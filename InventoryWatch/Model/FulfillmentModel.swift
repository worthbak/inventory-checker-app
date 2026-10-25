//
//  FulfillmentModel.swift
//  InventoryWatch
//
//  Created by Worth Baker on 10/25/22.
//

import Foundation

struct PickupRequestCooldown {
    private(set) var nextAllowedAt: Date?

    func check(now: Date = Date()) throws {
        if let nextAllowedAt, nextAllowedAt > now {
            throw AppError.pickupCooldown(until: nextAllowedAt)
        }
    }

    mutating func recordBlock(now: Date = Date(), retryAfter: Date? = nil) {
        deferRequests(until: max(now.addingTimeInterval(60), retryAfter ?? now))
    }

    mutating func deferRequests(until date: Date) {
        nextAllowedAt = max(nextAllowedAt ?? date, date)
    }

    mutating func recordSuccess() {
        nextAllowedAt = nil
    }

    static func retryAfterDate(_ value: String, now: Date = Date()) -> Date? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty, trimmed.allSatisfy({ $0.isASCII && $0.isNumber }),
           let seconds = TimeInterval(trimmed), seconds.isFinite {
            return now.addingTimeInterval(seconds)
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss z"
        return formatter.date(from: trimmed)
    }
}

actor FulfillmentModel {
    
    let defaultsVendor = DefaultsVendor()
    let skuDataLoader = SKUDataLoader()
    
    private var lastPickupRequestTime: Date = .distantPast
    private var lastStoreListRequestTime: Date = .distantPast
    private let minimumRequestInterval: TimeInterval = 3.0
    private var pickupCooldown = PickupRequestCooldown()
    
    var skuDataForPreferredProduct: SKUData {
        get async throws {
            return try await skuDataLoader.skuDataForPreferredProduct
        }
    }
    
    private var cachedStoreData: [String: StoreCountry] = [:]
    private let decoder = JSONDecoder()
    // Latest pickup API error keys (e.g., ["invalidLocalModelStore"]) captured from Apple JSON
    private(set) var lastPickupErrorKeys: [String] = []
    
    let session: URLSession

    init(session: URLSession? = nil) {
        self.session = session ?? Self.makeSession()
    }

    private static func makeSession() -> URLSession {
        let c = URLSessionConfiguration.ephemeral
        c.httpAdditionalHeaders = [:]
        c.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        c.httpCookieAcceptPolicy = .never
        c.httpShouldSetCookies = false
        c.httpCookieStorage = nil
        c.urlCredentialStorage = nil
        return URLSession(configuration: c)
    }
    
    private func applyBrowserHeaders(to request: inout URLRequest) {
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 30
    }
    
    private var modelParsingFilter: Set<String>? {
        let filterForPreferredModels = defaultsVendor.showResultsOnlyForPreferredModels
        var filterModels = filterForPreferredModels ? defaultsVendor.preferredSKUs : nil
        if let customSku = defaultsVendor.customSkuData?.sku {
            filterModels?.insert(customSku)
        }
        
        return filterModels
    }
    
    func loadStoresByCountry(country: Country) async throws -> [String: StoreCountry] {
        if cachedStoreData[country.locale] != nil {
            return cachedStoreData
        }

        do {
            // Try loading remote stores first
            let url = URL(string: "https://www.apple.com/rsp-web/store-list?locale=\(country.locale)")!
            var request = URLRequest(url: url)
            applyBrowserHeaders(to: &request)
            
            let timeSinceLastStoreRequest = Date().timeIntervalSince(lastStoreListRequestTime)
            if timeSinceLastStoreRequest < minimumRequestInterval {
                let delay = minimumRequestInterval - timeSinceLastStoreRequest
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
            lastStoreListRequestTime = Date()
            
            let (data, _) = try await session.data(for: request, delegate: nil)
            
            // Check if we received HTML instead of JSON
            if let responseString = String(data: data, encoding: .utf8) {
                if responseString.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("<") {
                    print("❌ Store list API returned HTML instead of JSON. Falling back to local data.")
                    throw AppError.invalidStoreResponse
                }
            }
            
            let jsonStores = try decoder.decode(StoreBootstrap.self, from: data)
            cachedStoreData.merge(jsonStores.countryData) { _, new in new }
            if cachedStoreData[country.locale] != nil { return cachedStoreData }
        } catch {
            print("Store list API error: \(error)")
        }
        
        // If remote stores failed to load, fallback to comprehensive global store data first
        let fileType = "json"
        
        // Try the comprehensive global store data first
        if let path = Bundle.main.path(forResource: "Stores_GlobalBootstrap", ofType: fileType) {
            do {
                let data = try Data(contentsOf: URL(fileURLWithPath: path))
                let jsonStores = try decoder.decode(StoreBootstrap.self, from: data)
                cachedStoreData = jsonStores.countryData
                print("✅ Using comprehensive global store data (536 stores across 26 countries)")
                if cachedStoreData[country.locale] != nil { return cachedStoreData }
            } catch {
                print("⚠️ Failed to load global store data, trying local fallback: \(error)")
            }
        }
        
        // Fallback to original local bootstrap if global data fails
        if let path = Bundle.main.path(forResource: "Stores_LocalBootstrap", ofType: fileType) {
            do {
                let data = try Data(contentsOf: URL(fileURLWithPath: path))
                let jsonStores = try decoder.decode(StoreBootstrap.self, from: data)
                cachedStoreData = jsonStores.countryData
                print("✅ Using local store bootstrap data")
                if cachedStoreData[country.locale] != nil { return cachedStoreData }
                throw AppError.invalidProjectState
            } catch {
                print("❌ Failed to load local store data: \(error)")
                throw error
            }
        } else {
            throw AppError.invalidProjectState
        }
    }
    
    func fetchInventory(searches: [SearchConfiguration]) async throws -> (searchResults: [SearchInventoryResult], skuData: SKUData) {
        guard searches.isEmpty == false else { throw AppError.productNotAvailableInRegion }
        try pickupCooldown.check()
        let groupedSearches = Dictionary(grouping: searches) { "\($0.countryCode):\($0.storeNumber)" }
        var searchResults: [SearchInventoryResult] = []
        var pickupErrors: [String] = []
        var combinedLookup: [String: String] = [:]
        var combinedOrder: [String] = []
        lastPickupErrorKeys = []

        for group in groupedSearches.values {
            guard let firstSearch = group.first,
                  let country = Countries[firstSearch.countryCode] else {
                throw AppError.invalidProjectState
            }
            guard let (query, groupSKUData, searchSKUs) = try await generateQueryString(
                searches: group,
                country: country,
                storeNumber: firstSearch.storeNumber
            ) else {
                searchResults.append(contentsOf: group.map {
                    SearchInventoryResult(search: $0, availableParts: [])
                })
                continue
            }
            let countryPath = country.shortcode == "US" ? "" : "\(country.shortcode.lowercased())/"
            let urlRoot = "https://www.apple.com/\(countryPath)shop/retail/pickup-message?"
            guard let apiURL = URL(string: urlRoot + query) else {
                throw AppError.couldNotGenerateURL
            }

            let stores = try await fetchInventory(
                from: apiURL,
                skuData: groupSKUData,
                preferredStoreNumber: firstSearch.storeNumber
            )
            pickupErrors.append(contentsOf: lastPickupErrorKeys)
            for search in group {
                let matchingSKUs = Set((await skuData(for: search, country: country))?.orderedSKUs ?? [])
                var searchMatchingSKUs = matchingSKUs
                if let customSku = defaultsVendor.customSkuData?.sku {
                    searchMatchingSKUs.insert(customSku)
                }
                let filteredStores = stores.compactMap { store, parts -> (FulfillmentStore, [PartAvailability])? in
                    let matchingParts = parts.filter { searchMatchingSKUs.contains($0.partNumber) }
                    guard matchingParts.isEmpty == false else { return nil }
                    return (store, matchingParts)
                }
                searchResults.append(SearchInventoryResult(search: search, availableParts: filteredStores))
            }
            for sku in searchSKUs {
                guard combinedOrder.contains(sku) == false else { continue }
                combinedOrder.append(sku)
                if let name = groupSKUData.productName(forSKU: sku) {
                    combinedLookup[sku] = name
                }
            }
        }

        lastPickupErrorKeys = Array(Set(pickupErrors)).sorted()
        return (searchResults, SKUData(orderedSKUs: combinedOrder, lookup: combinedLookup))
    }

    private func fetchInventory(
        from apiURL: URL,
        skuData: SKUData,
        preferredStoreNumber: String
    ) async throws -> [(FulfillmentStore, [PartAvailability])] {
        try pickupCooldown.check()
        let timeSinceLastPickup = Date().timeIntervalSince(lastPickupRequestTime)
        if timeSinceLastPickup < minimumRequestInterval {
            let waitTime = minimumRequestInterval - timeSinceLastPickup
            try await Task.sleep(nanoseconds: UInt64(waitTime * 1_000_000_000))
        }
        try Task.checkCancellation()
        try pickupCooldown.check()
        lastPickupRequestTime = Date()

        print("🌐 Pickup URL: \(apiURL.absoluteString)")
        var request = URLRequest(url: apiURL)
        applyBrowserHeaders(to: &request)
        request.httpShouldHandleCookies = false

        let (data, response) = try await session.data(for: request, delegate: nil)
        let httpResponse = response as? HTTPURLResponse
        let status = httpResponse?.statusCode ?? 0
        print("📥 Pickup response: status=\(status), bytes=\(data.count), content-type=\(httpResponse?.value(forHTTPHeaderField: "Content-Type") ?? "unknown")")
        let now = Date()
        let retryAfter = httpResponse?.value(forHTTPHeaderField: "Retry-After").flatMap {
            let date = PickupRequestCooldown.retryAfterDate($0, now: now)
            if date == nil { print("Invalid Retry-After header: \($0)") }
            return date
        }
        if status == 541 {
            pickupCooldown.recordBlock(now: now, retryAfter: retryAfter)
            try pickupCooldown.check(now: now)
        } else if status == 429 || (status == 503 && retryAfter != nil) {
            pickupCooldown.deferRequests(until: max(retryAfter ?? now.addingTimeInterval(60), now.addingTimeInterval(1)))
            try pickupCooldown.check(now: now)
        }
        if let error = errorForStatusCode(status) { throw error }

        do {
            let stores = try parseStoreResponse(
                data,
                response: httpResponse,
                filterForModels: modelParsingFilter,
                skuData: skuData,
                preferredStoreNumber: preferredStoreNumber
            )
            pickupCooldown.recordSuccess()
            return stores
        } catch AppError.botDetected {
            pickupCooldown.recordBlock(now: now, retryAfter: retryAfter)
            try pickupCooldown.check(now: now)
            throw AppError.botDetected
        }
    }

    private func generateQueryString(
        searches: [SearchConfiguration],
        country: Country,
        storeNumber: String
    ) async throws -> (String, SKUData, [String])? {
        guard searches.isEmpty == false else { throw AppError.productNotAvailableInRegion }

        var searchData: [(SearchConfiguration, SKUData)] = []
        for search in searches {
            guard search.token.isEmpty == false,
                  let data = await skuData(for: search, country: country) else {
                throw AppError.productNotAvailableInRegion
            }
            searchData.append((search, data))
        }

        let combinedSKUData = SKUData(
            orderedSKUs: unique(searchData.flatMap { $0.1.orderedSKUs }),
            lookup: searchData.reduce(into: [String: String]()) { lookup, search in
                for sku in search.1.orderedSKUs {
                    if let name = search.1.productName(forSKU: sku) {
                        lookup[sku] = name
                    }
                }
            }
        )
        let resolvedSKUs = try searchData.flatMap { entry -> [String] in
            let (search, data) = entry
            guard search.family.isMac else { return data.orderedSKUs }
            let fullPartNumbers = data.orderedSKUs.filter { $0.contains("/") }
            guard fullPartNumbers.isEmpty == false else { throw AppError.invalidCatalogData }
            return fullPartNumbers
        }
        let resolvedSKUSet = Set(resolvedSKUs)

        // Build final SKU order depending on user preference
        // When "Only show results for preferred models" is enabled, restrict to preferred SKUs (plus custom)
        let preferred = defaultsVendor.preferredSKUs
        let showOnlyPreferred = defaultsVendor.showResultsOnlyForPreferredModels
        var allSkus: [String] = []
        if showOnlyPreferred {
            // Preserve deterministic order based on the user's stored CSV order
            let preferredCsv = UserDefaults.standard.string(forKey: "preferredSKUs") ?? ""
            let preferredList = preferredCsv.split(separator: ",").map { String($0) }.filter { resolvedSKUSet.contains($0) }
            allSkus.append(contentsOf: preferredList)
        } else {
            // Keep selected favorites first, then include the remaining SKUs from every search.
            if preferred.isEmpty == false {
                let preferredCsv = UserDefaults.standard.string(forKey: "preferredSKUs") ?? ""
                let preferredList = preferredCsv.split(separator: ",").map { String($0) }.filter { resolvedSKUSet.contains($0) }
                allSkus.append(contentsOf: preferredList)
                let remainder = resolvedSKUs.filter { preferred.contains($0) == false }
                allSkus.append(contentsOf: remainder)
            } else {
                allSkus = resolvedSKUs
            }
        }
        // Always append custom SKU if present
        if let customSku = defaultsVendor.customSkuData?.sku, customSku.isEmpty == false {
            allSkus.append(customSku)
        }
        // Deduplicate while preserving order
        var seen = Set<String>()
        allSkus = allSkus.filter { sku in
            if seen.contains(sku) { return false }
            seen.insert(sku)
            return true
        }

        guard allSkus.isEmpty == false else { return nil }

        var queryItems: [String] = ["fae=true"]

        if !storeNumber.isEmpty {
            queryItems.append("store=\(storeNumber)")
        }

        queryItems.append("searchNearby=\(defaultsVendor.shouldIncludeNearbyStores)")
        queryItems.append("little=false")

        queryItems.append(contentsOf: allSkus
            .enumerated()
            .compactMap { next in
                guard next.element.isEmpty == false else {
                    return nil
                }
                
                let count = next.offset
                let sku = next.element
                return "parts.\(count)=\(sku)"
            })

        queryItems.append("mts.0=regular")
        queryItems.append("mts.1=sticky")
        queryItems.append("fts=true")
        
        return (queryItems.joined(separator: "&"), combinedSKUData, allSkus)
    }

    private func skuData(for search: SearchConfiguration, country: Country) async -> SKUData? {
        switch search.family {
        case .watch: return await skuDataLoader.watchSKUData(forToken: search.token, country: country)
        case .iphone: return await skuDataLoader.phoneSKUData(forToken: search.token, country: country)
        case .mac: return await skuDataLoader.macSKUData(forToken: search.token, country: country)
        case .ipad: return await skuDataLoader.ipadSKUData(forToken: search.token, country: country)
        case .airpods: return await skuDataLoader.airpodsSKUData(forToken: search.token, country: country)
        case .homepod: return await skuDataLoader.homepodSKUData(forToken: search.token, country: country)
        case .avp: return await skuDataLoader.avpSKUData(forToken: search.token, country: country)
        }
    }

    private func unique(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values.filter { seen.insert($0).inserted }
    }
    
    private func parseStoreResponse(
        _ responseData: Data?,
        response: HTTPURLResponse?,
        filterForModels: Set<String>?,
        skuData: SKUData,
        preferredStoreNumber: String
    ) throws -> [(FulfillmentStore, [PartAvailability])] {
        guard let responseData = responseData else {
            throw errorForStatusCode(response?.statusCode) ?? AppError.invalidStoreResponse
        }
        
        // Check if we received HTML instead of JSON
        if let responseString = String(data: responseData, encoding: .utf8) {
            if responseString.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("<") {
                print("❌ Received HTML instead of JSON. Response length: \(responseData.count) bytes")
                print("First 200 characters: \(String(responseString.prefix(200)))")
                
                // Check for common error patterns
                if responseString.contains("accessDenied") || responseString.contains("Access Denied") {
                    throw AppError.botDetected
                } else if responseString.contains("403") || responseString.contains("Forbidden") {
                    throw AppError.accessDenied
                } else if responseString.contains("404") || responseString.contains("Not Found") {
                    throw AppError.resourceNotFound
                } else if responseString.contains("rate limit") || responseString.contains("too many requests") {
                    throw AppError.rateLimited
                } else {
                    throw AppError.invalidStoreResponse
                }
            }
        }
        
        guard let json = try? JSONSerialization.jsonObject(with: responseData, options: []) as? [String : Any] else {
            print("❌ Failed to parse JSON. Response status: \(response?.statusCode ?? -1)")
            if let responseString = String(data: responseData, encoding: .utf8) {
                print("Response preview: \(String(responseString.prefix(200)))")
            }
            throw errorForStatusCode(response?.statusCode) ?? AppError.invalidStoreResponse
        }
        
        guard let body = json["body"] as? [String: Any] else {
            throw AppError.unexpectedJSONStructure
        }

        let storeList: [[String: Any]]
        if let stores = body["stores"] as? [[String: Any]] {
            storeList = stores
        } else if let content = body["content"] as? [String: Any],
                  let pickupMessage = content["pickupMessage"] as? [String: Any] {
            if let errors = pickupMessage["errorMessageKeys"] as? [String], errors.isEmpty == false {
                lastPickupErrorKeys = errors
                print("Apple pickup API errors (non-fatal): \(errors.joined(separator: ", "))")
            } else {
                lastPickupErrorKeys = []
            }
            storeList = pickupMessage["stores"] as? [[String: Any]] ?? []
        } else {
            throw AppError.unexpectedJSONStructure
        }
        
        let collectedStores: [FulfillmentStore] = storeList.compactMap { storeJSON -> FulfillmentStore? in
            guard let name = storeJSON["storeName"] as? String else { return nil }
            guard let number = storeJSON["storeNumber"] as? String else { return nil }
            guard let city = storeJSON["city"] as? String else { return nil }
            let state = storeJSON["state"] as? String
            
            guard let partsAvailability = storeJSON["partsAvailability"] as? [String: [String: Any]] else { return nil }
            let parsedParts: [PartAvailability] = partsAvailability.values.compactMap { part in
                guard
                    let availabilityString = part["pickupDisplay"] as? String,
                    let availability = PartAvailability.PickupAvailability(rawValue: availabilityString),
                    let messageTypes = part["messageTypes"] as? [String: Any],
                    let regular = messageTypes["regular"] as? [String: Any],
                    let availabilityStorePickupQuote = regular["storePickupQuote"] as? String
                else {
                    return nil
                }
                guard let partNumber = part["partNumber"] as? String else {
                    return nil
                }
                // get name from SKU data, or custom SKU if available
                let productName: String
                if let name = skuData.productName(forSKU: partNumber) {
                    productName = name
                } else if let customSku = defaultsVendor.customSkuData, partNumber == customSku.sku {
                    productName = customSku.nickname
                } else {
                    productName = partNumber
                }
                
                return PartAvailability(partNumber: partNumber, partName: productName, availability: availability, availabilityStorePickupQuote: availabilityStorePickupQuote)
            }
            
            
            
            let storeAddress = StoreAddress(city: city, address1: nil, address2: nil, stateName: state, stateCode: nil, postalCode: nil)
            let retailStore = RetailStore(id: number, name: name, telephone: "", slug: "", address: storeAddress)
            return FulfillmentStore(store: retailStore, partsAvailability: parsedParts)
        }
        
        return self.parseAvailableModels(
            from: collectedStores,
            filterForModels: filterForModels,
            preferredStoreNumber: preferredStoreNumber
        )
    }
    
    private func parseAvailableModels(
        from stores: [FulfillmentStore],
        filterForModels: Set<String>?,
        preferredStoreNumber: String
    ) -> [(FulfillmentStore, [PartAvailability])] {
        let allAvailableModels: [(FulfillmentStore, [PartAvailability])] = stores
            .compactMap { store in
                let rv: [PartAvailability] = store.partsAvailability.filter { part in
                    switch part.availability {
                    case .available:
                        if let filter = filterForModels, filter.contains(part.partNumber) == false {
                            return false
                        }
                        
                        return true
                    case .unavailable, .ineligible:
                        return false
                    }
                }
                
                if rv.isEmpty {
                    return nil
                } else {
                    return (store, rv)
                }
            }
        
        let prioritizedModels = allAvailableModels.enumerated().sorted { first, second in
            let firstIsPreferred = first.element.0.storeNumber == preferredStoreNumber
            let secondIsPreferred = second.element.0.storeNumber == preferredStoreNumber
            if firstIsPreferred != secondIsPreferred {
                return firstIsPreferred
            }
            return first.offset < second.offset
        }
        return prioritizedModels.map(\.element)
    }
    
    private func errorForStatusCode(_ statusCode: Int?) -> AppError? {
        guard let statusCode else {
            return nil
        }
        
        switch statusCode {
        case 403:
            return .accessDenied
        case 404:
            return .resourceNotFound
        case 429:
            return .rateLimited
        case 541:
            return .botDetected
        case 500...599:
            return .storeUnavailable
        default:
            return nil
        }
    }
    
}