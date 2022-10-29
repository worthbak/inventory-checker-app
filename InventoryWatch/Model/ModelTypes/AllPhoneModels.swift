//
//  AllPhoneModels.swift
//  InventoryWatch
//
//  Created by Worth Baker on 7/27/22.
//

import Foundation

struct AllPhoneModels {
    struct PhoneModel {
        let sku: String
        let productName: String
    }
    
    var proMax14: [PhoneModel]
    var pro14: [PhoneModel]
    var regular14: [PhoneModel]
    var plus14: [PhoneModel]
    
    var mini13: [PhoneModel]
    var regular13: [PhoneModel]
    
    func toSkuData(_ keypath: KeyPath<AllPhoneModels, [AllPhoneModels.PhoneModel]>) -> SKUData {
        let models = self[keyPath: keypath]
        
        let lookup: [String: String] = models.reduce(into: [:]) { acc, next in
            acc[next.sku] = next.productName
        }
        
        return SKUData(orderedSKUs: models.map { $0.sku }, lookup: lookup)
    }
}
