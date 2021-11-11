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
    
    fileprivate init(orderedSKUs: [String], lookup: [String: String]) {
        self.orderedSKUs = orderedSKUs
        self.skuLookup = lookup
    }
    
    func productName(forSKU sku: String) -> String? {
        return skuLookup[sku]
    }
}

func SkuDataForCountry(_ country: Country) -> SKUData {
    
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
//        "MYD92\(country.skuCode)/A"
    ]
    
    let skusToName = [
        "MKGR3\(country.skuCode)/A": "14\" M1 Pro 8 Core CPU 14 Core GPU 512GB Silver",
        "MKGP3\(country.skuCode)/A": "14\" M1 Pro 8 Core CPU 14 Core GPU 512GB Space Grey",
        "MKGT3\(country.skuCode)/A": "14\" M1 Pro 10 Core CPU 16 Core GPU 1TB Silver",
        "MKGQ3\(country.skuCode)/A": "14\" M1 Pro 10 Core CPU 16 Core GPU 1TB Space Grey",
        "MMQX3\(country.skuCode)/A": "14\" M1 Max 10 Core CPU 32 Core GPU 2TB Silver, Ultimate",
        "MKH53\(country.skuCode)/A": "14\" M1 Max 10 Core CPU 32 Core GPU 2TB Space Grey, Ultimate",
        "MK1H3\(country.skuCode)/A": "16\" M1 Max 10 Core CPU 32 Core GPU 1TB Silver",
        "MK1A3\(country.skuCode)/A": "16\" M1 Max 10 Core CPU 32 Core GPU 1TB Space Grey",
        "MMQW3\(country.skuCode)/A": "16\" M1 Max 10 Core CPU 32 Core GPU 4TB Silver, Ultimate",
        "MK233\(country.skuCode)/A": "16\" M1 Max 10 Core CPU 32 Core GPU 4TB Space Grey, Ultimate",
        "MK1F3\(country.skuCode)/A": "16\" M1 Pro 10 Core CPU 16 Core GPU 1TB Silver",
        "MK193\(country.skuCode)/A": "16\" M1 Pro 10 Core CPU 16 Core GPU 1TB Space Grey",
        "MK1E3\(country.skuCode)/A": "16\" M1 Pro 10 Core CPU 16 Core GPU 512GB Silver",
        "MK183\(country.skuCode)/A": "16\" M1 Pro 10 Core CPU 16 Core GPU 512GB Space Grey",
    ]
    
    return SKUData(orderedSKUs: orderedSkus, lookup: skusToName)
}

//let controlSku = "MYD92LL/A"
