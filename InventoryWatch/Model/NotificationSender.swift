//
//  NotificationSender.swift
//  InventoryWatch
//
//  Created by Worth Baker on 10/27/22.
//

import Foundation

struct NotificationSender {
    
    private let defaultsVendor = DefaultsVendor()
    
    func sendNotificationIfNeeded(availableParts: [(FulfillmentStore, [PartAvailability])], skuData: SKUData) async {
        var hasPreferredModel = false
        let preferredModels = defaultsVendor.preferredSKUs
        for model in availableParts {
            for submodel in model.1 {
                if hasPreferredModel == false && preferredModels.contains(submodel.partNumber) {
                    hasPreferredModel = true
                    break
                }
                
                if hasPreferredModel == false, let customSku = defaultsVendor.customSkuData?.sku, submodel.partNumber == customSku {
                    hasPreferredModel = true
                    break
                }
            }
        }
        
        if defaultsVendor.notifyOnlyForPreferredModels && !hasPreferredModel {
            return
        }
        
        let message = self.generateNotificationText(from: availableParts, skuData: skuData, preferredModels: preferredModels)
        NotificationManager.shared.sendNotification(title: hasPreferredModel ? "Preferred Model Found!" : "Apple Store Inventory", body: message)
    }
    
    private func generateNotificationText(from data: [(FulfillmentStore, [PartAvailability])], skuData: SKUData, preferredModels: Set<String>) -> String {
        guard data.isEmpty == false else {
            return "No Inventory Found"
        }
        
        let filterForPreferredModels = defaultsVendor.notifyOnlyForPreferredModels
        var collector: [PartAvailability: Int] = [:]
        for (_, parts) in data {
            for part in parts {
                if filterForPreferredModels, !preferredModels.contains(part.partNumber) {
                    continue
                }
                
                collector[part, default: 0] += 1
            }
        }
        
        let combined: [String] = collector.reduce(into: []) { partialResult, next in
            
            let (key, value) = next
            let name = key.partName
            partialResult.append("\(name): \(value) found")
        }
        
        return combined.joined(separator: ", ")
    }
    
}
