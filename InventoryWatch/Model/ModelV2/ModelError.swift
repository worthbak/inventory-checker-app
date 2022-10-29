//
//  ModelError.swift
//  InventoryWatch
//
//  Created by Worth Baker on 10/25/22.
//

import Foundation

enum AppError: Swift.Error, LocalizedError {
    case failedToParseGithubVersion
    case invalidLocalModelStore
    case invalidProjectState
    case couldNotGenerateURL
    case noStoresFound
    case storeUnavailable
    case invalidStoreResponse
    case unexpectedJSONStructure
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
        case .invalidStoreResponse, .unexpectedJSONStructure, .noStoresFound:
            return "Unexpected inventory data found. Please confirm that the selected store is valid for the selected country."
        case .storeUnavailable:
            return "Apple's fulfillment API returned an internal server error and is currently unavailable."
        case .invalidLocalModelStore, .invalidProjectState, .failedToParseGithubVersion:
            return "InventoryWatch has invalid or currupted local data. Please contact the developer (@worthbak)."
        case .generic(let optional):
            return "A network error occurred. Details: \(optional?.localizedDescription ?? "unknown")"
        }
    }
}
