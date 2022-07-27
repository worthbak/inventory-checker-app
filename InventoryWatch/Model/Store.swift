//
//  Store.swift
//  InventoryWatch
//
//  Created by Worth Baker on 7/27/22.
//

import Foundation

struct JsonStore: Codable, Equatable {
    var storeName: String
    var storeNumber: String
    var city: String
}

struct Store: Equatable {
    let storeName: String
    let storeNumber: String
    let city: String
    let state: String?
    
    var locationDescription: String {
        return [city, state].compactMap { $0 }.joined(separator: ", ")
    }
    
    let partsAvailability: [PartAvailability]
}
