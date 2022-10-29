//
//  AppleWatchData.swift
//  InventoryWatch
//
//  Created by Worth Baker on 10/27/22.
//

import Foundation



struct AppleWatchData {
    
    struct AppleWatchModel {
        let sku: SKUString
        let description: String
    }
    
    let alpine: [SKUString: AppleWatchModel]
    let trail: [SKUString: AppleWatchModel]
    let ocean: [SKUString: AppleWatchModel]
    
    init(from rawData: [String: [String: String]]) {
        var _alpine: [SKUString: AppleWatchModel] = [:]
        var _trail: [SKUString: AppleWatchModel] = [:]
        var _ocean: [SKUString: AppleWatchModel] = [:]
        
        for (key, value) in rawData {
            switch key {
            case "alpine":
                _alpine = value.reduce(into: [:], { partialResult, item in
                    partialResult[item.key] = AppleWatchModel(sku: item.key, description: item.value)
                })
            case "trail":
                _trail = value.reduce(into: [:], { partialResult, item in
                    partialResult[item.key] = AppleWatchModel(sku: item.key, description: item.value)
                })
            case "ocean":
                _ocean = value.reduce(into: [:], { partialResult, item in
                    partialResult[item.key] = AppleWatchModel(sku: item.key, description: item.value)
                })
            default:
                print("found unexpected Apple Watch Ultra band type: \(key)")
                continue
            }
        }
        
        alpine = _alpine
        trail = _trail
        ocean = _ocean
    }
    
    func toSkuData() -> SKUData {
        let allSkus: [SKUString] = [alpine, trail, ocean].flatMap { $0.keys }
        let lookup: [SKUString: String] = [alpine, trail, ocean].reduce(into: [:]) { partialResult, map in
            map.forEach { key, value in
                partialResult[key] = value.description
            }
        }
        
        return SKUData(orderedSKUs: allSkus, lookup: lookup)
    }
}
