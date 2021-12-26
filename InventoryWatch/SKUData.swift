//
//  SKUData.swift
//  InventoryWatch
//
//  Created by Worth Baker on 11/8/21.
//

import Foundation

struct SKUData {
    private let skuLookup: [String: String]
    let orderedSKUs: [String]
    
    init(orderedSKUs: [String], lookup: [String: String]) {
        self.orderedSKUs = orderedSKUs
        self.skuLookup = lookup
    }
    
    func productName(forSKU sku: String) -> String? {
        return skuLookup[sku]
    }
}

func iPadDataForCountry(_ country: Country, isWifi: Bool) -> SKUData {
    let skuCode = country.altSkuCode ?? country.skuCode
    
    let wifiData = [
        "MK7R3": "iPad Mini 64GB Purple Wifi",
        "MLWL3": "iPad Mini 64GB Pink Wifi",
        "MK7P3": "iPad Mini 64GB Starlight Wifi",
        "MK7M3": "iPad Mini 64GB Space Gray Wifi",
        "MK7X3": "iPad Mini 256GB Purple Wifi",
        "MLWR3": "iPad Mini 256GB Pink Wifi",
        "MK7V3": "iPad Mini 256GB Starlight Wifi",
        "MK7T3": "iPad Mini 256GB Space Gray Wifi"
    ]
    
    let cellData = [
        "MK8E3": "iPad Mini 64GB Purple Cellular",
        "MLX43": "iPad Mini 64GB Pink Cellular",
        "MK8C3": "iPad Mini 64GB Starlight Cellular",
        "MK893": "iPad Mini 64GB Space Gray Cellular",
        "MK8K3": "iPad Mini 256GB Purple Cellular",
        "MLX93": "iPad Mini 256GB Pink Cellular",
        "MK8H3": "iPad Mini 256GB Starlight Cellular",
        "MK8F3": "iPad Mini 256GB Space Gray Cellular"
    ]
    
    let orderedSkus = isWifi ?
    [ "MK7R3", "MLWL3", "MK7P3", "MK7M3", "MK7X3", "MLWR3", "MK7V3", "MK7T3" ] :
    [ "MK8E3", "MLX43", "MK8C3", "MK893", "MK8K3", "MLX93", "MK8H3", "MK8F3" ]
    
    let skusToName: [String: String] = orderedSkus.reduce(into: [String: String]()) { partialResult, next in
        let map = isWifi ? wifiData : cellData
        guard let name = map[next] else { return }
        
        let localSku = "\(next)\(skuCode)/A"
        partialResult[localSku] = name
    }
    
    let localOrderedSkus = orderedSkus.map { "\($0)\(skuCode)/A" }
    
    return SKUData(orderedSKUs: localOrderedSkus, lookup: skusToName)
}

func MBPDataForCountry(_ country: Country) -> SKUData {
    
    let orderedSkus = [
        "MKGR3\(country.skuCode)/A",
        "MKGP3\(country.skuCode)/A",
        "MKGT3\(country.skuCode)/A",
        "MKGQ3\(country.skuCode)/A",
        "MMQX3\(country.skuCode)/A",
        "MKH53\(country.skuCode)/A",
        "MK1E3\(country.skuCode)/A",
        "MK183\(country.skuCode)/A",
        "MK1F3\(country.skuCode)/A",
        "MK193\(country.skuCode)/A",
        "MK1H3\(country.skuCode)/A",
        "MK1A3\(country.skuCode)/A",
        "MK233\(country.skuCode)/A",
        "MMQW3\(country.skuCode)/A",
    ]
    
    /**
     see here for tweet containing all in-store models:
     https://twitter.com/caseyliss/status/1453007425188024324?s=20
     */
    let skusToName = [
        "MKGR3\(country.skuCode)/A": "14\" M1 Pro (8c CPU, 14c GPU) 16GB/512GB Silver",
        "MKGP3\(country.skuCode)/A": "14\" M1 Pro (8c CPU, 14c GPU) 16GB/512GB Space Grey",
        "MKGT3\(country.skuCode)/A": "14\" M1 Pro (10c CPU, 16c GPU) 16GB/512GB Silver",
        "MKGQ3\(country.skuCode)/A": "14\" M1 Pro (10c CPU, 16c GPU) 16GB/512GB Space Grey",
        "MMQX3\(country.skuCode)/A": "14\" M1 Max (10c CPU, 32c GPU) 64GB/512GB Silver, Ultimate",
        "MKH53\(country.skuCode)/A": "14\" M1 Max (10c CPU, 32c GPU) 64GB/512GB Space Grey, Ultimate",
        "MK1H3\(country.skuCode)/A": "16\" M1 Max (10c CPU, 32c GPU) 32GB/1TB Silver",
        "MK1A3\(country.skuCode)/A": "16\" M1 Max (10c CPU, 32c GPU) 32GB/1TB Space Grey",
        "MMQW3\(country.skuCode)/A": "16\" M1 Max (10c CPU, 32c GPU) 64GB/4TB Silver, Ultimate",
        "MK233\(country.skuCode)/A": "16\" M1 Max (10c CPU, 32c GPU) 64GB/4TB Space Grey, Ultimate",
        "MK1F3\(country.skuCode)/A": "16\" M1 Pro (10c CPU, 16c GPU) 16GB/512GB Silver",
        "MK193\(country.skuCode)/A": "16\" M1 Pro (10c CPU, 16c GPU) 16GB/512GB Space Grey",
        "MK1E3\(country.skuCode)/A": "16\" M1 Pro (10c CPU, 16c GPU) 16GB/1TB Silver",
        "MK183\(country.skuCode)/A": "16\" M1 Pro (10c CPU, 16c GPU) 16GB/1TB Space Grey",
    ]
    
    return SKUData(orderedSKUs: orderedSkus, lookup: skusToName)
}
