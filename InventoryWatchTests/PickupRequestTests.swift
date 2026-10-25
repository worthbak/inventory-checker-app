import Foundation
import Testing
@testable import InventoryWatch

private final class PickupStubProtocol: URLProtocol {
    private static let lock = NSLock()
    private static var count = 0
    private static var heldRequests: [PickupStubProtocol] = []

    static var requestCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return count
    }

    static func reset() {
        lock.lock()
        defer { lock.unlock() }
        count = 0
    }

    static func releaseResponses() {
        lock.lock()
        let requests = heldRequests
        heldRequests = []
        lock.unlock()
        for request in requests { request.respond() }
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.lock.lock()
        Self.count += 1
        let hold = request.value(forHTTPHeaderField: "X-Test-Hold") == "true"
        if hold { Self.heldRequests.append(self) }
        Self.lock.unlock()
        if !hold { respond() }
    }

    private func respond() {
        let status = Int(request.value(forHTTPHeaderField: "X-Test-Status") ?? "") ?? 541
        var headers = ["Content-Type": "text/html"]
        headers["Retry-After"] = request.value(forHTTPHeaderField: "X-Test-Retry-After")
        guard let url = request.url,
              let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: headers) else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data("<html>Access Denied</html>".utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {
        Self.lock.lock()
        Self.heldRequests.removeAll { $0 === self }
        Self.lock.unlock()
    }
}

@Suite(.serialized)
struct PickupRequestTests {
    @Test @MainActor
    func overlappingRefreshesShareOneInFlightRequestAndRespectCooldown() async throws {
        let defaults = UserDefaults.standard
        let savedSearches = defaults.object(forKey: "searchConfigurations")
        defer { defaults.set(savedSearches, forKey: "searchConfigurations") }
        let searches = [
            SearchConfiguration(family: .watch, token: "apple-watch", countryCode: "US", storeNumber: "R164")
        ]
        defaults.set(try JSONEncoder().encode(searches), forKey: "searchConfigurations")

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [PickupStubProtocol.self]
        configuration.httpAdditionalHeaders = ["X-Test-Hold": "true"]
        let session = URLSession(configuration: configuration)
        defer {
            PickupStubProtocol.releaseResponses()
            session.invalidateAndCancel()
        }
        PickupStubProtocol.reset()
        let model = ViewModel(fulfillmentModel: FulfillmentModel(session: session))

        await model.fetchLatestInventory()
        try await waitUntil { PickupStubProtocol.requestCount == 1 }
        for _ in 0..<3 { await model.fetchLatestInventory() }
        #expect(model.isLoading)
        #expect(PickupStubProtocol.requestCount == 1)

        PickupStubProtocol.releaseResponses()
        try await waitUntil { model.errorState != nil && !model.isLoading }
        await model.fetchLatestInventory()
        try await waitUntil { !model.isLoading }
        #expect(PickupStubProtocol.requestCount == 1)
        guard case .pickupCooldown = model.errorState else {
            Issue.record("Expected the UI to expose the shared cooldown")
            return
        }
    }

    @MainActor
    private func waitUntil(_ condition: () -> Bool) async throws {
        let deadline = Date().addingTimeInterval(5)
        while !condition() && Date() < deadline {
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        try #require(condition())
    }

    @Test(arguments: [541, 429, 503])
    func blockedResponsesStopFurtherRequestsAcrossSearches(status: Int) async throws {
        try await verifyBlockedResponse(status: status, retryAfter: "10800", minimumDelay: 10800)
    }

    @Test(arguments: [541, 429])
    func missingRetryAfterUsesConservativeDefaults(status: Int) async throws {
        try await verifyBlockedResponse(status: status, retryAfter: nil, minimumDelay: 60)
    }

    private func verifyBlockedResponse(status: Int, retryAfter: String?, minimumDelay: TimeInterval) async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [PickupStubProtocol.self]
        var headers = ["X-Test-Status": "\(status)"]
        headers["X-Test-Retry-After"] = retryAfter
        configuration.httpAdditionalHeaders = headers
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }
        PickupStubProtocol.reset()
        let model = FulfillmentModel(session: session)
        let searches = [
            SearchConfiguration(family: .watch, token: "apple-watch", countryCode: "US", storeNumber: "R164")
        ]
        let before = Date()
        do {
            _ = try await model.fetchInventory(searches: searches)
            Issue.record("Expected a blocked pickup response")
        } catch AppError.pickupCooldown(let until) {
            #expect(until >= before.addingTimeInterval(minimumDelay))
        }
        #expect(PickupStubProtocol.requestCount == 1)

        let otherSearches = [
            SearchConfiguration(family: .watch, token: "apple-watch", countryCode: "AT", storeNumber: "R687")
        ]
        do {
            _ = try await model.fetchInventory(searches: otherSearches)
            Issue.record("Expected the shared cooldown to reject another region")
        } catch AppError.pickupCooldown {
            #expect(PickupStubProtocol.requestCount == 1)
        }
        #expect(PickupStubProtocol.requestCount == 1)

        let newSessionModel = FulfillmentModel(session: session)
        do {
            _ = try await newSessionModel.fetchInventory(searches: searches)
            Issue.record("Expected the stub to return another blocked response")
        } catch AppError.pickupCooldown {
            #expect(PickupStubProtocol.requestCount == 2)
        }
        #expect(PickupStubProtocol.requestCount == 2)
    }
}
