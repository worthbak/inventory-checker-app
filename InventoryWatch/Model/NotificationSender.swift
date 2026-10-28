//
//  NotificationSender.swift
//  InventoryWatch
//
//  Created by Worth Baker on 10/27/22.
//

import Foundation

struct NotificationSender {
    
    private let defaultsVendor = DefaultsVendor()
    
    func sendNotificationIfNeeded(availableParts: [(FulfillmentStore, [PartAvailability])], hasPreferredModel: Bool, skuData: SKUData, searches: [SearchConfiguration]) async {
        let message = self.generateNotificationText(from: availableParts, skuData: skuData, searches: searches)
        let title = await generateNotificationTitle(hasPreferredModel: hasPreferredModel, availableParts: availableParts, skuData: skuData, searches: searches)
        await NotificationManager.shared.sendNotification(title: title, body: message)
    }
    
    private func generateNotificationText(from data: [(FulfillmentStore, [PartAvailability])], skuData: SKUData, searches: [SearchConfiguration]) -> String {
        guard data.isEmpty == false else {
            return "No inventory currently available at nearby stores"
        }
        
        var collector: [PartAvailability: Int] = [:]
        var storeNames: Set<String> = []
        
        for (store, parts) in data {
            storeNames.insert(store.storeName)
            for part in parts {
                collector[part, default: 0] += 1
            }
        }
        
        let sortedModels = collector.sorted { $0.value > $1.value }
        let modelCount = sortedModels.count
        let storeCount = storeNames.count
        
        if modelCount == 0 {
            return "No preferred models available at this time"
        }
        
        let topModels = sortedModels.prefix(3).map { (part, count) in
            var shortName = part.partName
            if searches.count == 1, let family = searches.first?.family {
                let prefix = "\(family.displayName) "
                if shortName.hasPrefix(prefix) {
                    shortName = String(shortName.dropFirst(prefix.count))
                }
            }
            return "\(shortName) (×\(count))"
        }
        
        let storeText = storeCount == 1 ? "1 store" : "\(storeCount) stores"
        let modelText = modelCount > 3 ? "& \(modelCount - 3) more" : ""
        
        let message = "\(topModels.joined(separator: ", ")) \(modelText) • Available at \(storeText)"
        return message.trimmingCharacters(in: .whitespaces)
    }
    
    private func generateNotificationTitle(hasPreferredModel: Bool, availableParts: [(FulfillmentStore, [PartAvailability])], skuData: SKUData, searches: [SearchConfiguration]) async -> String {
        let totalModels = availableParts.reduce(0) { total, storeParts in
            total + storeParts.1.count
        }
        
        let productName = searches.count == 1
            ? await getProductName(for: searches[0], skuData: skuData)
            : "Apple Products"
        let productEmoji = searches.count == 1 ? getProductEmoji(for: searches[0].family) : "📦"
        
        if hasPreferredModel {
            let emojis = ["🎉", "✨", "🔥", "⚡️", "🚀"]
            let randomEmoji = emojis.randomElement() ?? "🎉"
            return "\(randomEmoji) Your \(productName) is Available!"
        } else if totalModels > 10 {
            return "\(productEmoji) Lots of \(productName) Models Available"
        } else if totalModels > 0 {
            return "\(productEmoji) \(productName) Inventory Update"
        } else {
            return "\(productEmoji) Inventory Check Complete"
        }
    }
    
    private func getProductName(for search: SearchConfiguration, skuData: SKUData) async -> String {
        let family = search.family
        let country = Countries[search.countryCode] ?? defaultsVendor.preferredCountry
        if family.isWatch {
            if let display = await displayNameForWatchToken(token: search.token, country: country) {
                return display
            }
            return "Apple Watch"
        }
        if family.isIPhone {
            return "iPhone"
        }
        if family.isMac {
            return "Mac"
        }
        if family.isIPad {
            if let display = await displayNameForiPadToken(token: search.token, country: country) {
                return display
            }
            return "iPad"
        }
        if family.isAirPods {
            if let display = await displayNameForAirPodsToken(token: search.token, country: country) {
                return display
            }
            return "AirPods"
        }
        if family.isHomePod {
            if let display = await displayNameForHomePodToken(token: search.token, country: country) {
                return display
            }
            return "HomePod"
        }
        if family.isAVP {
            if let display = await displayNameForAVPToken(token: search.token, country: country) {
                return display
            }
            return "Apple Vision Pro"
        }
        // Fallback: infer from SKU names (should not typically be reached)
        for sku in skuData.orderedSKUs {
            if let productName = skuData.productName(forSKU: sku) {
                let n = productName.lowercased()
                if n.contains("iphone") { return "iPhone" }
                if n.contains("apple watch") || n.contains("watch") { return "Apple Watch" }
            }
        }
        return "iPhone"
    }

    private func displayNameForWatchToken(token: String, country: Country) async -> String? {
        // MainActor for JSONCatalogAppleWatch access
        return await MainActor.run {
            guard let dict = JSONCatalogAppleWatch.categoryData(for: country, sourcePage: token), let md = dict.values.first else { return nil }
            // Base name from familyName or family
            var baseName: String? = nil
            if let famName = md.familyName, famName.isEmpty == false {
                baseName = famName
            } else {
                let fam = md.family
                if fam == "apple_watch" {
                    baseName = "Apple Watch"
                } else if fam.isEmpty == false {
                    baseName = fam.replacingOccurrences(of: "_", with: " ").capitalized
                }
            }
            // Variant from token suffix
            var variant: String? = nil
            if token.hasPrefix("apple-watch-") {
                let suffix = String(token.dropFirst("apple-watch-".count))
                if suffix.isEmpty == false {
                    variant = (suffix.lowercased() == "se") ? "SE" : suffix.replacingOccurrences(of: "-", with: " ").capitalized
                }
            }
            if let base = baseName { return variant != nil ? "\(base) \(variant!)" : base }
            return nil
        }
    }

    private func displayNameForiPadToken(token: String, country: Country) async -> String? {
        return await MainActor.run {
            guard let dict = JSONCatalogiPad.categoryData(for: country, sourcePage: token), let md = dict.values.first else { return nil }
            if let famName = md.familyName, famName.isEmpty == false, famName.lowercased() != "unknown" {
                return famName
            }
            if md.family.isEmpty == false {
                return md.family.replacingOccurrences(of: "_", with: " ").capitalized
            }
            return token.replacingOccurrences(of: "-", with: " ").capitalized
        }
    }

    private func displayNameForAirPodsToken(token: String, country: Country) async -> String? {
        return await MainActor.run {
            guard let dict = JSONCatalogAirPods.categoryData(for: country, sourcePage: token), let md = dict.values.first else { return nil }
            if let famName = md.familyName, famName.isEmpty == false, famName.lowercased() != "unknown" {
                return famName
            }
            if md.family.isEmpty == false {
                return md.family.replacingOccurrences(of: "_", with: " ").capitalized
            }
            return token.replacingOccurrences(of: "-", with: " ").capitalized
        }
    }

    private func displayNameForHomePodToken(token: String, country: Country) async -> String? {
        return await MainActor.run {
            guard let dict = JSONCatalogHomePod.categoryData(for: country, sourcePage: token), let md = dict.values.first else { return nil }
            if let famName = md.familyName, famName.isEmpty == false, famName.lowercased() != "unknown" {
                return famName
            }
            if md.family.isEmpty == false {
                return md.family.replacingOccurrences(of: "_", with: " ").capitalized
            }
            return token.replacingOccurrences(of: "-", with: " ").capitalized
        }
    }

    private func displayNameForAVPToken(token: String, country: Country) async -> String? {
        return await MainActor.run {
            guard let dict = JSONCatalogAVP.categoryData(for: country, sourcePage: token), let md = dict.values.first else { return nil }
            if let famName = md.familyName, famName.isEmpty == false, famName.lowercased() != "unknown" {
                return famName
            }
            if md.family.isEmpty == false {
                return md.family.replacingOccurrences(of: "_", with: " ").capitalized
            }
            return token.replacingOccurrences(of: "-", with: " ").capitalized
        }
    }
    
    private func getProductEmoji(for family: ProductFamily) -> String {
        if family.isWatch { return "⌚️" }
        if family.isIPhone { return "📱" }
        if family.isMac { return "💻" }
        if family.isIPad { return "📱" }
        if family.isAirPods { return "🎧" }
        if family.isHomePod { return "🔊" }
        if family.isAVP { return "🥽" }
        return "📱"
    }
    
}
