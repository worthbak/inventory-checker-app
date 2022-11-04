//
//  Store.swift
//  InventoryWatch
//
//  Created by Worth Baker on 7/27/22.
//

import Foundation

#warning("Would be good to unify this model with `RetailStore`")
struct FulfillmentStore: Equatable {
    let storeName: String
    let storeNumber: String
    let city: String
    let state: String?
    
    var locationDescription: String {
        return [city, state].compactMap { $0 }.joined(separator: ", ")
    }
    
    let partsAvailability: [PartAvailability]
}
