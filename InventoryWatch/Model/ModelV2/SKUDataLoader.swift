//
//  ModelLoader.swift
//  InventoryWatch
//
//  Created by Worth Baker on 10/25/22.
//

import Foundation

actor SKUDataLoader {
    
    private enum iPhoneModel: CaseIterable {
        case thirteen, fourteen
    }
    
    var defaultsManager = DefaultsVendor()
    
    private var cachediPhoneData: [Country: AllPhoneModels] = [:]
    private var cachedAppleWatchUltraData: [CountryCode: AppleWatchData] = [:]
    
    var skuDataForPreferredProduct: SKUData {
        get async throws {
            return try await skuData(for: defaultsManager.preferredProductType, and: defaultsManager.preferredCountry)
        }
    }
    
    func skuData(for productType: ProductType, and country: Country) async throws -> SKUData {
        switch productType {
        case .MacBookPro:
            return MBPDataForCountry(country)
        case .M2MacBookPro13:
            return M2MBPDataForCountry(country)
        case .M2MacBookAir:
            return M2MBAirDataForCountry(country)
        case .MacStudio:
            return MacStudioDataForCountry(country)
            
        case .StudioDisplay:
            return StudioDisplayForCountry(country)
        case .AirPodsProGen2:
            return AirPodsProGen2DataForCountry(country)
        case .ApplePencilUSBCAdapter:
            return ApplePencilUSBCAdapterDataForCountry(country)
            
        case .iPadMiniWifi:
            return iPadMiniDataForCountry(country, isWifi: true)
        case .iPadMiniCellular:
            return iPadMiniDataForCountry(country, isWifi: false)
        case .iPad10thGenWifi:
            return iPad10thGenDataForCountry(country, isWifi: true)
        case .iPad10thGenCellular:
            return iPad10thGenDataForCountry(country, isWifi: false)
        case .iPadProM2_11in_Wifi:
            return iPadProM2_11inDataForCountry(country, isWifi: true)
        case .iPadProM2_11in_Cellular:
            return iPadProM2_11inDataForCountry(country, isWifi: false)
        case .iPadProM2_13in_Wifi:
            return iPadProM2_13inDataForCountry(country, isWifi: true)
        case .iPadProM2_13in_Cellular:
            return iPadProM2_13inDataForCountry(country, isWifi: false)
            
        case .iPhoneRegular13:
            return try phoneModels(for: country).toSkuData(\.regular13)
        case .iPhoneMini13:
            return try phoneModels(for: country).toSkuData(\.mini13)
        case .iPhoneRegular14:
            return try phoneModels(for: country).toSkuData(\.regular14)
        case .iPhonePlus14:
            return try phoneModels(for: country).toSkuData(\.plus14)
        case .iPhonePro14:
            return try phoneModels(for: country).toSkuData(\.pro14)
        case .iPhoneProMax14:
            return try phoneModels(for: country).toSkuData(\.proMax14)
            
        case .AppleWatchUltra:
            return try appleWatchUltraModels(for: country)
        }
    }
    
    private func generateiPhoneModelsByCountry() throws -> [Country: AllPhoneModels] {
        if cachediPhoneData.isEmpty == false {
            return cachediPhoneData
        }
        
        var rv = [Country: AllPhoneModels]()
        
        for phoneModel in iPhoneModel.allCases {
            let phoneModelsJson = try loadIPhoneModels(for: phoneModel)
            
            for (countryCode, phones) in phoneModelsJson {
                guard let country = Countries[countryCode.uppercased()] else {
                    throw AppError.invalidLocalModelStore
                }
                
                let unmappedModelsData: [(String, WritableKeyPath<AllPhoneModels, [AllPhoneModels.PhoneModel]>)]
                switch phoneModel {
                case .thirteen:
                    unmappedModelsData = [
                        ("mini13", \AllPhoneModels.mini13),
                        ("regular13", \AllPhoneModels.regular13)
                    ]
                case .fourteen:
                    unmappedModelsData = [
                        ("plus14", \AllPhoneModels.plus14),
                        ("regular14", \AllPhoneModels.regular14),
                        ("pro14", \AllPhoneModels.pro14),
                        ("proMax14", \AllPhoneModels.proMax14)
                    ]
                }
                
                let modelsData = unmappedModelsData.map { first, second in
                    return (phones[first], second)
                }
                
                var phoneModels: AllPhoneModels
                if let existing = rv[country] {
                    phoneModels = existing
                } else {
                    phoneModels = AllPhoneModels(proMax14: [], pro14: [], regular14: [], plus14: [], mini13: [], regular13: [])
                }
                
                for (models, keyPath) in modelsData {
                    guard let models = models else {
                        continue
                    }
                    
                    let parsed: [AllPhoneModels.PhoneModel] = models.map { modelData in
                        return AllPhoneModels.PhoneModel(sku: modelData.key, productName: modelData.value)
                    }
                    
                    phoneModels[keyPath: keyPath] = parsed
                }
                
                rv[country] = phoneModels
            }
        }
        
        cachediPhoneData = rv
        return rv
    }
    
    private func phoneModels(for country: Country) throws -> AllPhoneModels {
        let iPhoneModels = try generateiPhoneModelsByCountry()
        
        guard let models = iPhoneModels[country] else {
            throw AppError.invalidLocalModelStore
        }
        
        return models
    }
    
                                                                 // country: type:    model:   description
    private func loadIPhoneModels(for model: iPhoneModel) throws -> [String: [String: [String: String]]] {
        let location: String
        switch model {
        case .thirteen:
            location = "iPhoneModels13-intl"
        case .fourteen:
            location = "iPhoneModels14-intl"
        }
        
        if let path = Bundle.main.path(forResource: location, ofType: "json") {
            let data = try Data(contentsOf: URL(fileURLWithPath: path))
            let decoder = JSONDecoder()
            
            let iphoneData = try decoder.decode([String: [String: [String: String]]].self, from: data)
            return iphoneData
        } else {
            throw AppError.invalidProjectState
        }
    }
    
    private func appleWatchUltraModels(for country: Country) throws -> SKUData {
        let rawData = try loadAppleWatchUltraModels()
        if rawData.isEmpty {
            fatalError()
        }
        
        var compiled: [Country: AppleWatchData] = [:]
        for (countryCode, models) in rawData {
            guard let foundCountry = Countries[countryCode.uppercased()] else {
                throw AppError.invalidLocalModelStore
            }
            
            compiled[foundCountry] = models
        }
        
        guard let countryData = compiled[country] else {
            throw AppError.invalidLocalModelStore
        }
        
        return countryData.toSkuData()
    }
    
    private func loadAppleWatchUltraModels() throws -> [CountryCode: AppleWatchData] {
        if cachedAppleWatchUltraData.isEmpty == false {
            return cachedAppleWatchUltraData
        }
        
        if let path = Bundle.main.path(forResource: "AppleWatchUltra-intl", ofType: "json") {
            let data = try Data(contentsOf: URL(fileURLWithPath: path))
            let decoder = JSONDecoder()
            
            if let appleWatchData = try? decoder.decode([String: [String: [String: String]]].self, from: data) {
                let mapped: [CountryCode: AppleWatchData] = appleWatchData.reduce(into: [:]) { partialResult, item in
                    let data = AppleWatchData(from: item.value)
                    partialResult[item.key] = data
                }
                
                cachedAppleWatchUltraData = mapped
                return mapped
            } else {
                throw AppError.invalidLocalModelStore
            }
        } else {
            throw AppError.invalidProjectState
        }
    }
}




