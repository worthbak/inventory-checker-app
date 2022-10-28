//
//  Analytics.swift
//  InventoryWatch
//
//  Created by Worth Baker on 11/17/21.
//

import Foundation

struct AnalyticsData: Codable, Equatable {
    let localUUID: String
    let country: String
    let storeNumber: String?
    let productType: ProductType
    let preferredModels: String
    let updateInterval: Int
    let notifyOnlyForPreferredModels: Bool
    let hasCustomSku: Bool
    let appVersion: String
    
    var toJsonData: Data? {
        let dictionary: [String: Any] = [
            "localUUID": localUUID,
            "country": country,
            "storeNumber": storeNumber ?? "",
            "productType": productType.rawValue,
            "preferredModels": preferredModels,
            "updateInterval": updateInterval,
            "notifyOnlyForPreferredModels": notifyOnlyForPreferredModels,
            "hasCustomSku": hasCustomSku,
            "appVersion": appVersion
        ]
        
        let reduced = dictionary
            .map { key, value in
                return "\(key)=\(value)"
            }
            .joined(separator: "&")
        
        return reduced.data(using: String.Encoding.ascii)
    }
    
    private static func generateCurrentData() -> AnalyticsData {
        let defaults = UserDefaults.standard
        
        var localUUID = defaults.string(forKey: "localUUID")
        if localUUID == nil {
            localUUID = UUID().uuidString
            defaults.set(localUUID, forKey: "localUUID")
        }
        
        let preferredCountry = defaults.string(forKey: "preferredCountry")
        let preferredStoreNumber = defaults.string(forKey: "preferredStoreNumber")
        let preferredProductType = defaults.string(forKey: "preferredProductType") ?? "MacBookPro"
        let preferredSKUsString = defaults.string(forKey: "preferredSKUs") ?? ""
        let notifyOnlyForPreferredModels = defaults.bool(forKey: "notifyOnlyForPreferredModels")
        let preferredUpdateInterval = defaults.integer(forKey: "preferredUpdateInterval")
        let customSku = defaults.string(forKey: "customSku")
        
        return AnalyticsData(
            localUUID: localUUID!,
            country: preferredCountry ?? "US",
            storeNumber: preferredStoreNumber,
            productType: ProductType(rawValue: preferredProductType) ?? .MacBookPro,
            preferredModels: preferredSKUsString,
            updateInterval: preferredUpdateInterval,
            notifyOnlyForPreferredModels: notifyOnlyForPreferredModels,
            hasCustomSku: customSku != nil && customSku?.isEmpty == false,
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unkown_version"
        )
    }
    
    static func updateAnalyticsData() {
        let current = generateCurrentData()
        
        if let previousAnalyticsData = UserDefaults.standard.object(forKey: "previousAnalyticsData") as? Data {
            let decoder = JSONDecoder()
            if let last = try? decoder.decode(AnalyticsData.self, from: previousAnalyticsData) {
                if last == current {
                    // no change
                    return
                } else {
                    commitData(current)
                }
            } else {
                commitData(current)
            }
        } else {
            commitData(current)
        }
    }
    
    private static func commitData(_ data: AnalyticsData) {
        writeDataToDefaults(data)
        postUserSettings(data)
    }
    
    private static func writeDataToDefaults(_ data: AnalyticsData) {
        print(data)
        
        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(data) {
            UserDefaults.standard.set(encoded, forKey: "previousAnalyticsData")
        }
    }
    
    private static func postUserSettings(_ data: AnalyticsData) {
        // let urlString = "http://127.0.0.1:3002/user-settings"
        let urlString = "https://peaceful-island-18502.herokuapp.com/user-settings"
        guard let url = URL(string: urlString) else {
            return
        }
        
        Task {
            var request = URLRequest(url: url)
            
            let bodyData = data.toJsonData
            
            // Change the URLRequest to a POST request
            request.httpMethod = "POST"
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            request.httpBody = bodyData
            do {
                let (_, response) = try await URLSession.shared.data(for: request)
                print("successfully updated analytics: response code \((response as? HTTPURLResponse)?.statusCode ?? 0)")
            } catch {
                print(error)
            }
        }
    }
}
