//
//  ModelError.swift
//  InventoryWatch
//
//  Created by Worth Baker on 10/25/22.
//

import Foundation

#warning("unused - what to do with this? centralize?")
enum ModelError: Swift.Error, LocalizedError {
    case couldNotGenerateURL
    case invalidStoreResponse
    case storeUnavailable
    case failedToParseJSON
    case unexpectedJSONStructure
    case noStoresFound
    case invalidLocalModelStore
    case generic(Error?)
    
    var errorDescription: String? {
        switch self {
        case .generic(let error):
            return error?.localizedDescription ?? "unknown error"
        default:
            return "\(self)"
        }
    }
    
    var errorMessage: String {
        switch self {
        case .couldNotGenerateURL:
            return "InventoryWatch failed to construct a valid URL for your search."
        case .invalidStoreResponse, .failedToParseJSON, .unexpectedJSONStructure, .noStoresFound:
            return "Unexpected inventory data found. Please confirm that the selected store is valid for the selected country."
        case .storeUnavailable:
            return "Apple's fulfillment API returned a server-based error and is currently unavailable."
        case .invalidLocalModelStore:
            return "InventoryWatch has invalid or currupted local data. Please contact the developer (@worthbak)."
        case .generic(let optional):
            return "A network error occurred. Details: \(optional?.localizedDescription ?? "unknown")"
        }
    }
}
