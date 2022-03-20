//
//  FetchSku.swift
//  InventoryWatch
//
//  Created by Worth Baker on 3/20/22.
//

import Foundation

struct ProductSku: Codable {
    let partNumber: String
    let displayName: String
    
    func skuForCountry(_ countryCode: String, using delimiter: String) -> String {
        return partNumber.replacingOccurrences(of: delimiter, with: countryCode)
    }
}

struct ProductData: Codable {
    let key: String
    let displayName: String
    let skus: [ProductSku]
}

struct iPhoneModelProductData: Codable {
    let countries: [String]
    let modelKeys: [String: String]
    let countryData: [
        String: // country key
            [String: // model key
                [String: String] // map of skus to display names
            ]
    ]
}

struct iPhoneProductData: Codable {
    let key: String
    let skus: iPhoneModelProductData
}

struct RemoteSkuData: Codable {
    let countryDelimiter: String
    let productData: [ProductData]
    let iPhoneProductData: [iPhoneProductData]
}

enum SkuError: Swift.Error {
    case failedToLoadLocalJson
    case localParsingError(Swift.Error)
}

func fetchSkuData(_ callback: (Result<RemoteSkuData, SkuError>) -> Void) {
    guard
        let path = Bundle.main.path(forResource: "LocalSkuData", ofType: "json"),
        let data = try? Data(contentsOf: URL(fileURLWithPath: path))
    else {
        callback(.failure(.failedToLoadLocalJson))
        return
    }
    
    do {
        let result = try JSONDecoder().decode(RemoteSkuData.self, from: data)
        callback(.success(result))
    } catch {
        callback(.failure(.localParsingError(error)))
    }
}
