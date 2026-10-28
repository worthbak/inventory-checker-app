//
//  DefaultsVendor.swift
//  InventoryWatch
//
//  Created by Worth Baker on 10/25/22.
//

import Foundation
import Combine

enum LegacyPreferencesMigration {
    static let previousBundleIdentifier = "com.worthbak.InventoryWatch"

    private static let migrationKey = "didMigratePreferencesFrom.\(previousBundleIdentifier)"

    static func migrateIfNeeded() {
        guard let currentBundleIdentifier = Bundle.main.bundleIdentifier else {
            preconditionFailure("The app bundle identifier is unavailable.")
        }
        migrate(
            using: .standard,
            from: previousBundleIdentifier,
            to: currentBundleIdentifier
        )
    }

    @discardableResult
    static func migrate(
        using defaults: UserDefaults,
        from oldDomain: String,
        to newDomain: String
    ) -> Bool {
        var newPreferences = defaults.persistentDomain(forName: newDomain) ?? [:]
        guard newPreferences[migrationKey] == nil else { return false }

        let oldPreferences = defaults.persistentDomain(forName: oldDomain) ?? [:]
        for (key, value) in oldPreferences where newPreferences[key] == nil {
            newPreferences[key] = value
        }
        newPreferences[migrationKey] = true
        defaults.setPersistentDomain(newPreferences, forName: newDomain)
        return oldPreferences.isEmpty == false
    }
}

// Minimal product family selector for token-driven UI
enum ProductFamily: String, Codable, CaseIterable, Identifiable {
    case watch = "watch"
    case iphone = "iphone"
    case mac = "mac"
    case ipad = "ipad"
    case airpods = "airpods"
    case homepod = "homepod"
    case avp = "avp"
    var id: Self { self }
    var isWatch: Bool { self == .watch }
    var isIPhone: Bool { self == .iphone }
    var isMac: Bool { self == .mac }
    var isIPad: Bool { self == .ipad }
    var isAirPods: Bool { self == .airpods }
    var isHomePod: Bool { self == .homepod }
    var isAVP: Bool { self == .avp }

    func searchDisplayName(modelName: String) -> String {
        if modelName.lowercased().hasPrefix(displayName.lowercased()) {
            return modelName
        }
        return "\(displayName) \(modelName)"
    }

    var displayName: String {
        switch self {
        case .watch: return "Apple Watch"
        case .iphone: return "iPhone"
        case .mac: return "Mac"
        case .ipad: return "iPad"
        case .airpods: return "AirPods"
        case .homepod: return "HomePod"
        case .avp: return "Apple Vision Pro"
        }
    }
}

struct SearchConfiguration: Codable, Hashable, Identifiable {
    var id: UUID
    var family: ProductFamily
    var token: String
    var countryCode: String
    var storeNumber: String
    var customSku: String
    var customSkuNickname: String
    var preferredSKUs: Set<String>
    var showOnlyPreferredModels: Bool
    var notifyOnlyForPreferredModels: Bool
    var includeNearbyStores: Bool

    /// Preferred SKUs that belong to this search's catalog; empty means no preference applies.
    func effectivePreferredSKUs(in catalog: some Collection<String>) -> Set<String> {
        preferredSKUs.intersection(catalog)
    }

    var customSkuData: (sku: String, nickname: String)? {
        let sku = customSku.trimmingCharacters(in: .whitespacesAndNewlines)
        guard sku.isEmpty == false else { return nil }
        return (sku, customSkuNickname.isEmpty ? sku : customSkuNickname)
    }

    init(
        id: UUID = UUID(),
        family: ProductFamily,
        token: String,
        countryCode: String = "US",
        storeNumber: String = "",
        customSku: String = "",
        customSkuNickname: String = "",
        preferredSKUs: Set<String> = [],
        showOnlyPreferredModels: Bool = false,
        notifyOnlyForPreferredModels: Bool = false,
        includeNearbyStores: Bool = true
    ) {
        self.id = id
        self.family = family
        self.token = token
        self.countryCode = countryCode
        self.storeNumber = storeNumber
        self.customSku = customSku
        self.customSkuNickname = customSkuNickname
        self.preferredSKUs = preferredSKUs
        self.showOnlyPreferredModels = showOnlyPreferredModels
        self.notifyOnlyForPreferredModels = notifyOnlyForPreferredModels
        self.includeNearbyStores = includeNearbyStores
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        family = try container.decode(ProductFamily.self, forKey: .family)
        token = try container.decode(String.self, forKey: .token)
        countryCode = try container.decodeIfPresent(String.self, forKey: .countryCode)
            ?? (UserDefaults.standard.string(forKey: "preferredCountry") ?? "US")
        storeNumber = try container.decodeIfPresent(String.self, forKey: .storeNumber)
            ?? UserDefaults.standard.preferredStoreNumber
        // Searches saved before custom SKUs became per-search inherit the old global value.
        customSku = try container.decodeIfPresent(String.self, forKey: .customSku)
            ?? (UserDefaults.standard.string(forKey: "customSku") ?? "")
        customSkuNickname = try container.decodeIfPresent(String.self, forKey: .customSkuNickname)
            ?? (UserDefaults.standard.string(forKey: "customSkuNickname") ?? "")
        let defaults = UserDefaults.standard
        preferredSKUs = try container.decodeIfPresent(Set<String>.self, forKey: .preferredSKUs)
            ?? defaults.preferredSKUsFromLegacyPreferences
        showOnlyPreferredModels = try container.decodeIfPresent(Bool.self, forKey: .showOnlyPreferredModels)
            ?? defaults.bool(forKey: "showResultsOnlyForPreferredModels")
        notifyOnlyForPreferredModels = try container.decodeIfPresent(Bool.self, forKey: .notifyOnlyForPreferredModels)
            ?? defaults.bool(forKey: "notifyOnlyForPreferredModels")
        includeNearbyStores = try container.decodeIfPresent(Bool.self, forKey: .includeNearbyStores)
            ?? (defaults.object(forKey: "shouldIncludeNearbyStores") as? Bool ?? true)
    }
}

extension UserDefaults {

    var preferredSKUsFromLegacyPreferences: Set<String> {
        Set((string(forKey: "preferredSKUs") ?? "").split(separator: ",").map(String.init))
    }

    @objc dynamic var preferredStoreNumber: String {
        get { string(forKey: "preferredStoreNumber") ?? "" }
        set { setValue(newValue, forKey: "preferredStoreNumber") }
    }
    
    @objc dynamic var lastUpdateDate: String? {
        get { string(forKey: "lastUpdateDate") }
        set { setValue(newValue, forKey: "lastUpdateDate") }
    }
    
    @objc dynamic var preferredUpdateInterval: Int {
        get {
            if let currentValue = object(forKey: "preferredUpdateInterval") as? Int {
                return currentValue
            } else {
                // WB 10/28/22: Changing default update interval from 1min to 5min
                let presetValue = 5
                set(presetValue, forKey: "preferredUpdateInterval")
                
                return presetValue
            }
        }
        set { setValue(newValue, forKey: "preferredUpdateInterval") }
    }
}

struct DefaultsVendor {
    
    var preferredCountry: Country {
        let value = UserDefaults.standard.string(forKey: "preferredCountry") ?? "US"
        
        return Countries[value] ?? USData
    }
    
    var preferredProductFamily: ProductFamily {
        // Reuse same storage key for backward compatibility
        let value = UserDefaults.standard.string(forKey: "preferredProductType") ?? ProductFamily.iphone.rawValue
        if let fam = ProductFamily(rawValue: value) { return fam }
        // Legacy ProductType raw values
        switch value {
        case "MacBookPro", "M2MacBookPro13", "M2MacBookAir", "MacStudio", "StudioDisplay":
            return .mac
        case "iPadMiniWifi", "iPadMiniCellular", "iPad10thGenWifi", "iPad10thGenCellular",
             "iPadProM2_11in_Wifi", "iPadProM2_11in_Cellular", "iPadProM2_13in_Wifi", "iPadProM2_13in_Cellular":
            return .ipad
        case "AppleWatchUltra":
            return .watch
        default:
            return .iphone
        }
    }
    
    var countryPathElement: String {
        let country = preferredCountry
        if country.shortcode == "US" {
            return ""
        } else {
            return country.shortcode.lowercased() + "/"
        }
    }
    
    var preferredStoreNumber: String {
        get { return UserDefaults.standard.preferredStoreNumber }
        nonmutating set { UserDefaults.standard.preferredStoreNumber = newValue }
    }
    
    var lastUpdateDate: String? {
        get { return UserDefaults.standard.lastUpdateDate }
        nonmutating set { UserDefaults.standard.lastUpdateDate = newValue }
    }
    
    // unused - keeping this around as an example implementation
    private var preferredStoreNumberStream: AnyPublisher<String, Never> {
        return UserDefaults.standard
            .publisher(for: \.preferredStoreNumber)
            .eraseToAnyPublisher()
    }
    
    var preferredUpdateInterval: Int {
        return UserDefaults.standard.preferredUpdateInterval
    }
    
    var notificationCooldownHours: Int {
        let val = UserDefaults.standard.integer(forKey: "notificationCooldownHours")
        return val > 0 ? val : 24
    }

    // Token-driven Apple Watch selection
    var preferredWatchToken: String {
        UserDefaults.standard.string(forKey: "preferredWatchToken") ?? ""
    }

    // Token-driven iPhone selection
    var preferredPhoneToken: String {
        UserDefaults.standard.string(forKey: "preferredPhoneToken") ?? ""
    }

    // Token-driven Mac selection
    var preferredMacToken: String {
        UserDefaults.standard.string(forKey: "preferredMacToken") ?? ""
    }

    var preferrediPadToken: String {
        UserDefaults.standard.string(forKey: "preferrediPadToken") ?? ""
    }

    var preferredAirPodsToken: String {
        UserDefaults.standard.string(forKey: "preferredAirPodsToken") ?? ""
    }

    var preferredHomePodToken: String {
        UserDefaults.standard.string(forKey: "preferredHomePodToken") ?? ""
    }

    var preferredAVPToken: String {
        UserDefaults.standard.string(forKey: "preferredAVPToken") ?? ""
    }
}
