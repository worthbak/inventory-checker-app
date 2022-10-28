//
//  Helpers.swift
//  InventoryWatch
//
//  Created by Worth Baker on 3/19/22.
//

import Foundation

typealias SKUString = String
typealias CountryCode = String

extension Array where Element == String {
  func sortedNumerically() -> [Element] {
    sorted { lhs, rhs in
      lhs.compare(rhs, options: [.numeric], locale: .current) == .orderedAscending
    }
  }
}

func compareNumeric(_ version1: String, _ version2: String) -> ComparisonResult {
  return version1.compare(version2, options: .numeric)
}

// From: https://github.com/JohnSundell/AsyncCompatibilityKit/blob/main/Sources/URLSession%2BAsync.swift
@available(macOS, deprecated: 12.0, message: "AsyncCompatibilityKit is only useful when targeting iOS versions earlier than 15")
public extension URLSession {
    /// Start a data task with a URL using async/await.
    /// - parameter url: The URL to send a request to.
    /// - returns: A tuple containing the binary `Data` that was downloaded,
    ///   as well as a `URLResponse` representing the server's response.
    /// - throws: Any error encountered while performing the data task.
    func data(from url: URL) async throws -> (Data, URLResponse) {
        try await data(for: URLRequest(url: url))
    }

    /// Start a data task with a `URLRequest` using async/await.
    /// - parameter request: The `URLRequest` that the data task should perform.
    /// - returns: A tuple containing the binary `Data` that was downloaded,
    ///   as well as a `URLResponse` representing the server's response.
    /// - throws: Any error encountered while performing the data task.
    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        var dataTask: URLSessionDataTask?
        
        return try await withTaskCancellationHandler(
            operation: {
                try await withCheckedThrowingContinuation { continuation in
                    dataTask = self.dataTask(with: request) { data, response, error in
                        guard let data = data, let response = response else {
                            let error = error ?? URLError(.badServerResponse)
                            return continuation.resume(throwing: error)
                        }
                        
                        continuation.resume(returning: (data, response))
                    }
                    
                    dataTask?.resume()
                }
            },
            onCancel: { [dataTask] in
                dataTask?.cancel()
            }
        )
    }
}
