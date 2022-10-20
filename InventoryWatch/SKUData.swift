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

func iPadProM2_11inDataForCountry(_ country: Country, isWifi: Bool) -> SKUData {
    let skuCode = country.skuCode(for: isWifi ? .iPadProM2_11in_Wifi : .iPadProM2_11in_Cellular) ?? country.skuCode
    
    let cellData = [
        "MP563": "M2 iPad Pro 11in 128GB Silver Cellular",
        "MP583": "M2 iPad Pro 11in 256GB Silver Cellular",
        "MP5D3": "M2 iPad Pro 11in 512GB Silver Cellular",
        "MP5F3": "M2 iPad Pro 11in 1TB Silver Cellular",
        "MP5H3": "M2 iPad Pro 11in 2TB Silver Cellular",
        "MP553": "M2 iPad Pro 11in 128GB Space_gray Cellular",
        "MP573": "M2 iPad Pro 11in 256GB Space_gray Cellular",
        "MP593": "M2 iPad Pro 11in 512GB Space_gray Cellular",
        "MP5E3": "M2 iPad Pro 11in 1TB Space_gray Cellular",
        "MP5G3": "M2 iPad Pro 11in 2TB Space_gray Cellular"
    ]
    
    let wifiData = [
        "MNXE3": "M2 iPad Pro 11in 128GB Silver Wifi",
        "MNXG3": "M2 iPad Pro 11in 256GB Silver Wifi",
        "MNXJ3": "M2 iPad Pro 11in 512GB Silver Wifi",
        "MNXL3": "M2 iPad Pro 11in 1TB Silver Wifi",
        "MNXN3": "M2 iPad Pro 11in 2TB Silver Wifi",
        "MNXD3": "M2 iPad Pro 11in 128GB Space_gray Wifi",
        "MNXF3": "M2 iPad Pro 11in 256GB Space_gray Wifi",
        "MNXH3": "M2 iPad Pro 11in 512GB Space_gray Wifi",
        "MNXK3": "M2 iPad Pro 11in 1TB Space_gray Wifi",
        "MNXM3": "M2 iPad Pro 11in 2TB Space_gray Wifi"
    ]
    
    let orderedSkus = isWifi ?
    ["MNXE3", "MNXG3", "MNXJ3", "MNXL3", "MNXN3", "MNXD3", "MNXF3", "MNXH3", "MNXK3", "MNXM3"] :
    ["MNXE3", "MNXG3", "MNXJ3", "MNXL3", "MNXN3", "MNXD3", "MNXF3", "MNXH3", "MNXK3", "MNXM3"]
    
    let skusToName: [String: String] = orderedSkus.reduce(into: [String: String]()) { partialResult, next in
        let map = isWifi ? wifiData : cellData
        guard let name = map[next] else { return }
        
        let localSku = "\(next)\(skuCode)/A"
        partialResult[localSku] = name
    }
    
    let localOrderedSkus = orderedSkus.map { "\($0)\(skuCode)/A" }
    
    return SKUData(orderedSKUs: localOrderedSkus, lookup: skusToName)
}

func iPadProM2_13inDataForCountry(_ country: Country, isWifi: Bool) -> SKUData {
    let skuCode = country.skuCode(for: isWifi ? .iPadProM2_13in_Wifi : .iPadProM2_13in_Cellular) ?? country.skuCode
    
    let cellData = [
        "MP5Y3": "M2 iPad Pro 12.9in 128GB Silver Cellular",
        "MP613": "M2 iPad Pro 12.9in 256GB Silver Cellular",
        "MP633": "M2 iPad Pro 12.9in 512GB Silver Cellular",
        "MP653": "M2 iPad Pro 12.9in 1TB Silver Cellular",
        "MP673": "M2 iPad Pro 12.9in 2TB Silver Cellular",
        "MP5X3": "M2 iPad Pro 12.9in 128GB Space_gray Cellular",
        "MP603": "M2 iPad Pro 12.9in 256GB Space_gray Cellular",
        "MP623": "M2 iPad Pro 12.9in 512GB Space_gray Cellular",
        "MP643": "M2 iPad Pro 12.9in 1TB Space_gray Cellular",
        "MP663": "M2 iPad Pro 12.9in 2TB Space_gray Cellular"
    ]
    
    let wifiData = [
        "MNXQ3": "M2 iPad Pro 12.9in 128GB Silver Wifi",
        "MNXT3": "M2 iPad Pro 12.9in 256GB Silver Wifi",
        "MNXV3": "M2 iPad Pro 12.9in 512GB Silver Wifi",
        "MNXX3": "M2 iPad Pro 12.9in 1TB Silver Wifi",
        "MNY03": "M2 iPad Pro 12.9in 2TB Silver Wifi",
        "MNXP3": "M2 iPad Pro 12.9in 128GB Space_gray Wifi",
        "MNXR3": "M2 iPad Pro 12.9in 256GB Space_gray Wifi",
        "MNXU3": "M2 iPad Pro 12.9in 512GB Space_gray Wifi",
        "MNXW3": "M2 iPad Pro 12.9in 1TB Space_gray Wifi",
        "MNXY3": "M2 iPad Pro 12.9in 2TB Space_gray Wifi"
    ]
    
    let orderedSkus = isWifi ?
    ["MNXQ3", "MNXT3", "MNXV3", "MNXX3", "MNY03", "MNXP3", "MNXR3", "MNXU3", "MNXW3", "MNXY3"] :
    ["MP5Y3", "MP613", "MP633", "MP653", "MP673", "MP5X3", "MP603", "MP623", "MP643", "MP663"]
    
    let skusToName: [String: String] = orderedSkus.reduce(into: [String: String]()) { partialResult, next in
        let map = isWifi ? wifiData : cellData
        guard let name = map[next] else { return }
        
        let localSku = "\(next)\(skuCode)/A"
        partialResult[localSku] = name
    }
    
    let localOrderedSkus = orderedSkus.map { "\($0)\(skuCode)/A" }
    
    return SKUData(orderedSKUs: localOrderedSkus, lookup: skusToName)
}

func iPad10thGenDataForCountry(_ country: Country, isWifi: Bool) -> SKUData {
    let skuCode = country.skuCode(for: isWifi ? .iPad10thGenWifi : .iPad10thGenCellular) ?? country.skuCode
    
    let wifiData = [
        "MPQ13": "iPad (10th Gen) 64GB Blue Wifi",
        "MPQ93": "iPad (10th Gen) 256GB Blue Wifi",
        "MPQ33": "iPad (10th Gen) 64GB Pink Wifi",
        "MPQC3": "iPad (10th Gen) 256GB Pink Wifi",
        "MPQ03": "iPad (10th Gen) 64GB Silver Wifi",
        "MPQ83": "iPad (10th Gen) 256GB Silver Wifi",
        "MPQ23": "iPad (10th Gen) 64GB Yellow Wifi",
        "MPQA3": "iPad (10th Gen) 256GB Yellow Wifi"
    ]
    
    let cellData = [
        "MQ6K3": "iPad (10th Gen) 64GB Blue Cellular",
        "MQ6U3": "iPad (10th Gen) 256GB Blue Cellular",
        "MQ6M3": "iPad (10th Gen) 64GB Pink Cellular",
        "MQ6W3": "iPad (10th Gen) 256GB Pink Cellular",
        "MQ6J3": "iPad (10th Gen) 64GB Silver Cellular",
        "MQ6T3": "iPad (10th Gen) 256GB Silver Cellular",
        "MQ6L3": "iPad (10th Gen) 64GB Yellow Cellular",
        "MQ6V3": "iPad (10th Gen) 256GB Yellow Cellular"
    ]
    
    let orderedSkus = isWifi ?
    ["MPQ13", "MPQ93", "MPQ33", "MPQC3", "MPQ03", "MPQ83", "MPQ23", "MPQA3"] :
    ["MQ6K3", "MQ6U3", "MQ6M3", "MQ6W3", "MQ6J3", "MQ6T3", "MQ6L3", "MQ6V3"]
    
    let skusToName: [String: String] = orderedSkus.reduce(into: [String: String]()) { partialResult, next in
        let map = isWifi ? wifiData : cellData
        guard let name = map[next] else { return }
        
        let localSku = "\(next)\(skuCode)/A"
        partialResult[localSku] = name
    }
    
    let localOrderedSkus = orderedSkus.map { "\($0)\(skuCode)/A" }
    
    return SKUData(orderedSKUs: localOrderedSkus, lookup: skusToName)
}

func iPadMiniDataForCountry(_ country: Country, isWifi: Bool) -> SKUData {
    let skuCode = country.skuCode(for: isWifi ? .iPadMiniWifi : .iPadMiniCellular) ?? country.skuCode
    
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

func StudioDisplayForCountry(_ country: Country) -> SKUData {
    let skuCode = country.skuCode(for: .StudioDisplay) ?? country.skuCode
    
    let orderedSkus = [
        "MK0U3\(skuCode)/A",
        "MK0Q3\(skuCode)/A",
        "MMYQ3\(skuCode)/A",
        "MMYW3\(skuCode)/A",
        "MMYV3\(skuCode)/A",
        "MMYX3\(skuCode)/A"
    ]
    
    let skusToName = [
        "MK0U3\(skuCode)/A": "Studio Display - Standard glass - Tilt-adjustable stand",
        "MK0Q3\(skuCode)/A": "Studio Display - Standard glass - Tilt- and height-adjustable stand",
        "MMYQ3\(skuCode)/A": "Studio Display - Standard glass - VESA mount adapter",
        "MMYW3\(skuCode)/A": "Studio Display - Nano-texture glass - Tilt-adjustable stand",
        "MMYV3\(skuCode)/A": "Studio Display - Nano-texture glass - Tilt- and height-adjustable stand",
        "MMYX3\(skuCode)/A": "Studio Display - Nano-texture glass - VESA mount adapter"
    ]
    
    return SKUData(orderedSKUs: orderedSkus, lookup: skusToName)
}

func MacStudioDataForCountry(_ country: Country) -> SKUData {
    let skuCode = country.skuCode(for: .MacStudio) ?? country.skuCode
    
    let orderedSkus = [
        "MJMW3\(skuCode)/A",
        "MJMV3\(skuCode)/A"
    ]
    
    let skusToName = [
        "MJMV3\(skuCode)/A": "M1 Max (10c CPU, 24c GPU), 32GB RAM, 512GB SSD",
        "MJMW3\(skuCode)/A": "M1 Ultra (20c CPU, 48c GPU), 64GB RAM, 1TB SSD"
    ]
    
    return SKUData(orderedSKUs: orderedSkus, lookup: skusToName)
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
        "MKGT3\(country.skuCode)/A": "14\" M1 Pro (10c CPU, 16c GPU) 16GB/1TB Silver",
        "MKGQ3\(country.skuCode)/A": "14\" M1 Pro (10c CPU, 16c GPU) 16GB/1TB Space Grey",
        "MMQX3\(country.skuCode)/A": "14\" M1 Max (10c CPU, 32c GPU) 64GB/2TB Silver, Ultimate",
        "MKH53\(country.skuCode)/A": "14\" M1 Max (10c CPU, 32c GPU) 64GB/2TB Space Grey, Ultimate",
        
        "MK1E3\(country.skuCode)/A": "16\" M1 Pro (10c CPU, 16c GPU) 16GB/512GB Silver",
        "MK183\(country.skuCode)/A": "16\" M1 Pro (10c CPU, 16c GPU) 16GB/512GB Space Grey",
        "MK1F3\(country.skuCode)/A": "16\" M1 Pro (10c CPU, 16c GPU) 16GB/1TB Silver",
        "MK193\(country.skuCode)/A": "16\" M1 Pro (10c CPU, 16c GPU) 16GB/1TB Space Grey",
        
        "MK1H3\(country.skuCode)/A": "16\" M1 Max (10c CPU, 32c GPU) 32GB/1TB Silver",
        "MK1A3\(country.skuCode)/A": "16\" M1 Max (10c CPU, 32c GPU) 32GB/1TB Space Grey",
        "MMQW3\(country.skuCode)/A": "16\" M1 Max (10c CPU, 32c GPU) 64GB/4TB Silver, Ultimate",
        "MK233\(country.skuCode)/A": "16\" M1 Max (10c CPU, 32c GPU) 64GB/4TB Space Grey, Ultimate",
    ]
    
    return SKUData(orderedSKUs: orderedSkus, lookup: skusToName)
}

func M2MBPDataForCountry(_ country: Country) -> SKUData {
    
    let orderedSkus = [
        "MNEH3\(country.skuCode)/A", // sg low
        "MNEJ3\(country.skuCode)/A", // sg high
        "MNEP3\(country.skuCode)/A", // sv low
        "MNEQ3\(country.skuCode)/A"  // sv high
    ]
    
    let skusToName = [
        "MNEH3\(country.skuCode)/A": "13\" M2 8GB/256GB - Space Gray",
        "MNEJ3\(country.skuCode)/A": "13\" M2 8GB/512GB - Space Gray",
        "MNEP3\(country.skuCode)/A": "13\" M2 8GB/256GB - Silver",
        "MNEQ3\(country.skuCode)/A": "13\" M2 8GB/512GB - Silver"
    ]
    
    return SKUData(orderedSKUs: orderedSkus, lookup: skusToName)
}

func M2MBAirDataForCountry(_ country: Country) -> SKUData {
    
    let orderedSkus = [
        "MLXY3\(country.skuCode)/A",
        "MLY03\(country.skuCode)/A",
        "MLY13\(country.skuCode)/A",
        "MLY23\(country.skuCode)/A",
        "MLY43\(country.skuCode)/A",
        "MLY33\(country.skuCode)/A",
        "MLXX3\(country.skuCode)/A",
        "MLXW3\(country.skuCode)/A",
        "MN703\(country.skuCode)/A",
        "MNQP3\(country.skuCode)/A",
        "MN6Y3\(country.skuCode)/A"
    ]
    
    let skusToName = [
        "MLXY3\(country.skuCode)/A": "M2 (8c CPU, 8c GPU) 8GB/256GB Silver",
        "MLY03\(country.skuCode)/A": "M2 (8c CPU, 10c GPU) 8GB/512GB Silver",
        "MLY13\(country.skuCode)/A": "M2 (8c CPU, 8c GPU) 8GB/256GB Starlight",
        "MLY23\(country.skuCode)/A": "M2 (8c CPU, 10c GPU) 8GB/512GB Starlight",
        "MLY43\(country.skuCode)/A": "M2 (8c CPU, 10c GPU) 8GB/512GB Midnight",
        "MLY33\(country.skuCode)/A": "M2 (8c CPU, 8c GPU) 8GB/256GB Midnight",
        "MLXX3\(country.skuCode)/A": "M2 (8c CPU, 10c GPU) 8GB/512GB Space Gray",
        "MLXW3\(country.skuCode)/A": "M2 (8c CPU, 8c GPU) 8GB/256GB Space Gray",
        
        // ultimate builds
        "MN703\(country.skuCode)/A": "M2 (8c CPU, 10c GPU) 16GB/1TB Midnight",
        "MNQP3\(country.skuCode)/A": "M2 (8c CPU, 10c GPU) 16GB/1TB Space Gray",
        "MN6Y3\(country.skuCode)/A": "M2 (8c CPU, 10c GPU) 16GB/1TB Starlight"
    ]
    
    return SKUData(orderedSKUs: orderedSkus, lookup: skusToName)
}

func AirPodsProGen2DataForCountry(_ country: Country) -> SKUData {
    let skuCode = country.skuCode(for: .AirPodsProGen2) ?? country.skuCode
    
    return SKUData(
        orderedSKUs: ["MQD83\(skuCode)/A"],
        lookup: ["MQD83\(skuCode)/A": "AirPods Pro (2nd Generation)"]
    )
}
