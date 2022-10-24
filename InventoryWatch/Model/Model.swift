//
//  Model.swift
//  InventoryWatch
//
//  Created by Worth Baker on 11/8/21.
//

import Foundation

enum ModelError: Swift.Error, LocalizedError {
    case couldNotGenerateURL
    case invalidStoreResponse
    case storeUnavailable
    case failedToParseJSON
    case unexpectedJSONStructure
    case noStoresFound
    case invalidLocalModelStore
    case generic(Error?)
    
    var errorDescription: String? {
        switch self {
        case .generic(let error):
            return error?.localizedDescription ?? "unknown error"
        default:
            return "\(self)"
        }
    }
    
    var errorMessage: String {
        switch self {
        case .couldNotGenerateURL:
            return "InventoryWatch failed to construct a valid URL for your search."
        case .invalidStoreResponse, .failedToParseJSON, .unexpectedJSONStructure, .noStoresFound:
            return "Unexpected inventory data found. Please confirm that the selected store is valid for the selected country."
        case .storeUnavailable:
            return "Apple's fulfillment API returned a server-based error and is currently unavailable."
        case .invalidLocalModelStore:
            return "InventoryWatch has invalid or currupted local data. Please contact the developer (@worthbak)."
        case .generic(let optional):
            return "A network error occurred. Details: \(optional?.localizedDescription ?? "unknown")"
        }
    }
}

struct ModelLoader {
    
    private enum iPhoneModel: CaseIterable {
        case thirteen, fourteen
    }
    
    lazy private var iPhoneModels: [Country: AllPhoneModels] = {
        var rv = [Country: AllPhoneModels]()
        
        for phoneModel in iPhoneModel.allCases {
            let phoneModelsJson = loadIPhoneModels(for: phoneModel)
            
            for (countryCode, phones) in phoneModelsJson {
                guard let country = Countries[countryCode.uppercased()] else {
                    self.updateErrorState(to: ModelError.invalidLocalModelStore)
                    return [:]
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
        
        return rv
    }()
    
    func skuData(for productType: ProductType, and country: Country) -> SKUData {
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
            return phoneModels(for: country).toSkuData(\.regular13)
        case .iPhoneMini13:
            return phoneModels(for: country).toSkuData(\.mini13)
        case .iPhoneRegular14:
            return phoneModels(for: country).toSkuData(\.regular14)
        case .iPhonePlus14:
            return phoneModels(for: country).toSkuData(\.plus14)
        case .iPhonePro14:
            return phoneModels(for: country).toSkuData(\.pro14)
        case .iPhoneProMax14:
            return phoneModels(for: country).toSkuData(\.proMax14)
            
        case .AppleWatchUltra:
            return appleWatchUltraModels(for: country)
        }
    }
    
    func phoneModels(for country: Country) -> AllPhoneModels {
        guard let models = iPhoneModels[country] else {
            self.updateErrorState(to: ModelError.invalidLocalModelStore)
            return AllPhoneModels(proMax14: [], pro14: [], regular14: [], plus14: [], mini13: [], regular13: [])
        }
        
        return models
    }
                                                           // country: type:    model:   description
    private func loadIPhoneModels(for model: iPhoneModel) -> [String: [String: [String: String]]] {
            let location: String
            switch model {
            case .thirteen:
                if let cached = cachedPhoneData13 {
                    return cached
                } else {
                    location = "iPhoneModels13-intl"
                }
            case .fourteen:
                if let cached = cachedPhoneData14 {
                    return cached
                } else {
                    location = "iPhoneModels14-intl"
                }
            }
            
            if let path = Bundle.main.path(forResource: location, ofType: "json") {
                do {
                    let data = try Data(contentsOf: URL(fileURLWithPath: path))
                    let decoder = JSONDecoder()
                    
                    if let iphoneData = try? decoder.decode([String: [String: [String: String]]].self, from: data) {
                        switch model {
                        case .thirteen: cachedPhoneData13 = iphoneData
                        case .fourteen: cachedPhoneData14 = iphoneData
                        }
                        
                        return iphoneData
                    } else {
                        return [:]
                    }
                    
                } catch {
                    print(error)
                    return [:]
                }
            } else {
                return [:]
            }
        }
    
    func appleWatchUltraModels(for country: Country) -> SKUData {
        let rawData = loadAppleWatchUltraModels()
        if rawData.isEmpty {
            fatalError()
        }
        
        var compiled: [Country: [String: [String: String]]] = [:]
        for (countryCode, models) in rawData {
            guard let foundCountry = Countries[countryCode.uppercased()] else {
                self.updateErrorState(to: ModelError.invalidLocalModelStore)
                return SKUData(orderedSKUs: [], lookup: [:])
            }
            
            compiled[foundCountry] = models
        }
        
        guard let countryData = compiled[country] else {
            self.updateErrorState(to: ModelError.invalidLocalModelStore)
            return SKUData(orderedSKUs: [], lookup: [:])
        }
        
        var allSKUs = [String]()
        var map = [String: String]()
        for (_, models) in countryData {
            for (sku, model) in models {
                allSKUs.append(sku)
                map[sku] = model
            }
        }
        
        return SKUData(orderedSKUs: allSKUs, lookup: map)
    }
    
    private func loadAppleWatchUltraModels() -> [String: [String: [String: String]]] {
        if let cachedAppleWatchData {
            return cachedAppleWatchData
        }
        
        if let path = Bundle.main.path(forResource: "AppleWatchUltra-intl", ofType: "json") {
            do {
                let data = try Data(contentsOf: URL(fileURLWithPath: path))
                let decoder = JSONDecoder()
                
                if let appleWatchData = try? decoder.decode([String: [String: [String: String]]].self, from: data) {
                    cachedAppleWatchData = appleWatchData
                    
                    return appleWatchData
                } else {
                    return [:]
                }
                
            } catch {
                print(error)
                return [:]
            }
        } else {
            return [:]
        }
    }
}

actor FulfillmentModel {
    
    func loadStoresByCountry() async throws -> [String: StoreCountry] {
        let decoder = JSONDecoder()
        
        do {
            // Try loading remote stores first
            let url = URL(string: "https://www.apple.com/rsp-web/store-list?locale=en_US")!
            let (data, _) = try await URLSession.shared.data(from: url)
            let jsonStores = try decoder.decode(StoreBootstrap.self, from: data)
            return jsonStores.countryData
        } catch {
            print(error)
        }
        
        // If remote stores failed to load, fallback to local bootstrap
        let fileType = "json"
        if let path = Bundle.main.path(forResource: "Stores_LocalBootstrap", ofType: fileType) {
            do {
                let data = try Data(contentsOf: URL(fileURLWithPath: path))
                
                let jsonStores = try decoder.decode(StoreBootstrap.self, from: data)
                return jsonStores.countryData
                
            } catch {
                print(error)
                throw error
            }
        } else {
            throw ModelError.invalidLocalModelStore
        }
    }
    
    
    
}

actor GithubModel {
    func fetchLatestGithubRelease() {
        guard
            let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
            let url = URL(string: "https://api.github.com/repos/worthbak/inventory-checker-app/tags")
        else {
            return
        }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            guard let data = data, let parsed = try? JSONDecoder().decode([GithubTag].self, from: data) else {
                return
            }
            
            let processedData = parsed
                .filter { !$0.name.hasPrefix("v") }
                .sorted { first, second in
                    switch compareNumeric(first.name, second.name) {
                    case .orderedAscending, .orderedSame:
                        return false
                    case .orderedDescending:
                        return true
                    }
                }
            
            guard let latestReleaseVersion = processedData.first?.name else {
                return
            }
            
            let isLatestRelease: Bool
            switch compareNumeric(latestReleaseVersion, appVersion) {
            case .orderedAscending, .orderedSame:
                isLatestRelease = true
            case .orderedDescending:
                isLatestRelease = false
            }
            
            DispatchQueue.main.async {
                print("Has \(isLatestRelease ? "latest" : "outdated") version: local: \(appVersion), remote: \(latestReleaseVersion)")
                self.hasLatestVersion = isLatestRelease
            }
        }
        .resume()
    }
}

@MainActor
final class ViewModel {
    
    
    
    private let fulfillmentModel = FulfillmentModel()
    private let defaultsVendor = DefaultsVendor()
    
    @Published var availableParts: [(FulfillmentStore, [PartAvailability])] = []
    @Published var isLoading = false
    @Published var hasLatestVersion = true
    @Published var errorState: ModelError?
    
    private var country: Country { Countries[defaultsVendor.preferredCountry] ?? USData }
    
    @Published var preferredStoreName: String? = nil
    
    private var updateTimer: Timer?
    
    // Published? function?
    var storesForCurrentCountry: [RetailStore] {
        get async {
            let storesByCountry = try? await fulfillmentModel.loadStoresByCountry()
            guard let storesByCountry else {
                print(ModelError.invalidLocalModelStore.localizedDescription)
                return []
            }
            
            guard let stores = storesByCountry[country.locale]?.stores else {
                // Probably should handle this error state more intelligently
                return []
            }
            
            return stores .sorted(by: { first, second in
                if let firstState = first.address.stateName, let secondState = second.address.stateName {
                    return firstState < secondState
                } else {
                    return first.name < second.name
                }
            })
        }
    }
    
}

struct DefaultsVendor {
    var preferredCountry: String {
        return UserDefaults.standard.string(forKey: "preferredCountry") ?? "US"
    }
    
    var preferredProductType: String {
        return UserDefaults.standard.string(forKey: "preferredProductType") ?? "MacBookPro"
    }
    
    var countryPathElement: String {
        let country = preferredCountry
        if country == "US" {
            return ""
        } else {
            return country + "/"
        }
    }
    
    var preferredStoreNumber: String {
        return UserDefaults.standard.string(forKey: "preferredStoreNumber") ?? "R032"
    }
    
    private var shouldIncludeNearbyStores: Bool {
        let value = UserDefaults.standard.object(forKey: "shouldIncludeNearbyStores") as? Bool
        
        return value ?? true
    }
    
    
    
    var preferredSKUs: Set<String> {
        guard let defaults = UserDefaults.standard.string(forKey: "preferredSKUs") else {
            return []
        }
        
        return defaults.components(separatedBy: ",").reduce(into: Set<String>()) { partialResult, next in
            partialResult.insert(next)
        }
    }
}

@MainActor
final class Model: ObservableObject {
    
    
    
    
    
    
    private var cachedPhoneData13: [String: [String: [String: String]]]?
    private var cachedPhoneData14: [String: [String: [String: String]]]?
    private var cachedAppleWatchData: [String: [String: [String: String]]]?
    
    
    private var preferredStoreInfoBacking: RetailStore?
    
    
    
    
    
    
    
    
    private let isTest: Bool
    
    init(isTest: Bool = false) {
        self.isTest = isTest
    }
    
    func clearCurrentAvailableParts() {
        availableParts = []
    }
    
    func updateErrorState(to error: Error?, deactivateLoadingState: Bool = true) {
        DispatchQueue.main.async {
            if deactivateLoadingState {
                self.isLoading = false
            }
            
            print(error?.localizedDescription ?? "errorState: nil")
            guard let error = error else {
                self.errorState = nil
                return
            }
            
            if let modelError = error as? ModelError {
                self.errorState = modelError
            } else {
                self.errorState = ModelError.generic(error)
            }
        }
    }
    
    
    
    #warning("move this to a better spot! and clean up the async code!")
    private var currentTask: URLSessionDataTask?
    
    func fetchLatestInventory() async {
        guard !isTest else {
            return
        }
        
        await syncPreferredStore()
        isLoading = true
        currentTask?.cancel()
        
        self.fetchLatestGithubRelease()
        self.updateErrorState(to: .none, deactivateLoadingState: false)
        
        let filterForPreferredModels = UserDefaults.standard.bool(forKey: "showResultsOnlyForPreferredModels")
        var filterModels = filterForPreferredModels ? preferredSKUs : nil
        if let customSku = customSkuData?.sku {
            filterModels?.insert(customSku)
        }
        
        let urlRoot = "https://www.apple.com/\(countryPathElement.lowercased())shop/fulfillment-messages?"
        let query = generateQueryString()
        
        guard let url = URL(string: urlRoot + query) else {
            updateErrorState(to: ModelError.couldNotGenerateURL)
            return
        }
        
        // Log the URL for debugging
        print(url.absoluteString)
        
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            
            Task { @MainActor in self.currentTask = nil }
            
            if let error = error as? URLError, error.code == .cancelled {
                print("duplicate URL task cancelled")
                return
            }
            
            do {
                try self.parseStoreResponse(data, response: response as? HTTPURLResponse, filterForModels: filterModels)
            } catch {
                self.updateErrorState(to: error)
            }
        }
            
        currentTask = task
        task.resume()
        
        var updateInterval = UserDefaults.standard.integer(forKey: "preferredUpdateInterval")
        if UserDefaults.standard.object(forKey: "preferredUpdateInterval") == nil {
            updateInterval = 1
            UserDefaults.standard.set(updateInterval, forKey: "preferredUpdateInterval")
        }
        
        if let existingTimer = updateTimer, existingTimer.timeInterval != Double(updateInterval * 60) {
            existingTimer.invalidate()
            updateTimer = nil
        }
        
        // Create new update timer if the user-setting is not "Never" (0) and
        // a timer does not already exist
        if updateInterval > 0 && updateTimer == nil {
            let interval = Double(updateInterval * 60)
            updateTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true, block: { _ in
                Task { await self.fetchLatestInventory() }
            })
        }
        
        AnalyticsData.updateAnalyticsData()
    }
    
    private func errorForStatusCode(_ statusCode: Int?) -> ModelError? {
        guard let statusCode else {
            return nil
        }
        
        switch statusCode {
        case 500...599:
            return .storeUnavailable
        default:
            return nil
        }
    }
    
    private func parseStoreResponse(_ responseData: Data?, response: HTTPURLResponse?, filterForModels: Set<String>?) throws {        
        guard let responseData = responseData else {
            throw errorForStatusCode(response?.statusCode) ?? ModelError.invalidStoreResponse
        }
        
        guard let json = try? JSONSerialization.jsonObject(with: responseData, options: []) as? [String : Any] else {
            throw errorForStatusCode(response?.statusCode) ?? ModelError.invalidStoreResponse
        }
        
        guard
            let body = json["body"] as? [String: Any],
                let content = body["content"] as? [String: Any],
                let pickupMessage = content["pickupMessage"] as? [String: Any]
        else {
            throw ModelError.unexpectedJSONStructure
        }
        
        guard let storeList = pickupMessage["stores"] as? [[String: Any]] else {
            throw ModelError.noStoresFound
        }
        
        let collectedStores: [FulfillmentStore] = storeList.compactMap { storeJSON in
            guard let name = storeJSON["storeName"] as? String else { return nil }
            guard let number = storeJSON["storeNumber"] as? String else { return nil }
            guard let city = storeJSON["city"] as? String else { return nil }
            let state = storeJSON["state"] as? String
            
            guard let partsAvailability = storeJSON["partsAvailability"] as? [String: [String: Any]] else { return nil }
            let parsedParts: [PartAvailability] = partsAvailability.values.compactMap { part in
                guard let partNumber = part["partNumber"] as? String else { return nil }
                guard
                    let availabilityString = part["pickupDisplay"] as? String,
                    let availability = PartAvailability.PickupAvailability(rawValue: availabilityString)
                else {
                    return nil
                }
                
                return PartAvailability(partNumber: partNumber, availability: availability)
            }
            
            return FulfillmentStore(storeName: name, storeNumber: number, city: city, state: state, partsAvailability: parsedParts)
        }
        
        try self.parseAvailableModels(from: collectedStores, filterForModels: filterForModels)
    }
    
    private func parseAvailableModels(from stores: [FulfillmentStore], filterForModels: Set<String>?) throws {
        let allAvailableModels: [(FulfillmentStore, [PartAvailability])] = stores
            .sorted(by: { first, _ in
                // always put preferred store first
                return first.storeNumber == preferredStoreNumber
            })
            .compactMap { store in
                let rv: [PartAvailability] = store.partsAvailability.filter { part in
                    switch part.availability {
                    case .available:
                        if let filter = filterForModels, filter.contains(part.partNumber) == false {
                            return false
                        }
                        
                        return true
                    case .unavailable, .ineligible:
                        return false
                    }
                }
                
                if rv.isEmpty {
                    return nil
                } else {
                    return (store, rv)
                }
        }
        
        DispatchQueue.main.async {
            self.availableParts = allAvailableModels
            self.isLoading = false
            self.updateErrorState(to: .none)
            
            let df = DateFormatter()
            df.dateFormat = "MMM d, h:mm a"
            let str = df.string(from: Date())
            UserDefaults.standard.setValue(str, forKey: "lastUpdateDate")
            
            var hasPreferredModel = false
            let preferredModels = self.preferredSKUs
            for model in allAvailableModels {
                for submodel in model.1 {
                    if hasPreferredModel == false && preferredModels.contains(submodel.partNumber) {
                        hasPreferredModel = true
                        break
                    }
                    
                    if hasPreferredModel == false, let customSku = self.customSkuData?.sku, submodel.partNumber == customSku {
                        hasPreferredModel = true
                        break
                    }
                }
            }
            
            if !self.isTest {
                if UserDefaults.standard.bool(forKey: "notifyOnlyForPreferredModels") && !hasPreferredModel {
                    return
                }
                
                let message = self.generateNotificationText(from: allAvailableModels)
                NotificationManager.shared.sendNotification(title: hasPreferredModel ? "Preferred Model Found!" : "Apple Store Inventory", body: message)
            }
        }
    }
    
    private func generateNotificationText(from data: [(FulfillmentStore, [PartAvailability])]) -> String {
        guard data.isEmpty == false else {
            return "No Inventory Found"
        }
        
        var collector: [String: Int] = [:]
        for (_, parts) in data {
            for part in parts {
                collector[part.partNumber, default: 0] += 1
            }
        }
        
        let combined: [String] = collector.reduce(into: []) { partialResult, next in
            let (key, value) = next
            let name = skuData.productName(forSKU: key) ?? key
            partialResult.append("\(name): \(value) found")
        }
        
        return combined.joined(separator: ", ")
    }
    
    private var customSkuData: (sku: String, nickname: String)? {
        guard
            let sku = UserDefaults.standard.string(forKey: "customSku"),
            let name = UserDefaults.standard.string(forKey: "customSkuNickname")
        else {
            return nil
        }
        
        return (sku, name)
    }
    
    private func generateQueryString() -> String {
        var allSkus = skuData.orderedSKUs
        if let customSku = customSkuData?.sku {
            allSkus.append(customSku)
        }
        
        var queryItems: [String] = allSkus
            .enumerated()
            .compactMap { next in
                guard next.element.isEmpty == false else {
                    return nil
                }
                
                let count = next.offset
                let sku = next.element
                return "parts.\(count)=\(sku)"
            }
        
        queryItems.append("searchNearby=\(shouldIncludeNearbyStores)")
        queryItems.append("store=\(preferredStoreNumber)")
        
        return queryItems.joined(separator: "&")
    }
    
    func productName(forSKU sku: String) -> String {
        if let name = skuData.productName(forSKU: sku) {
            return name
        } else if let custom = customSkuData?.sku, custom == sku {
            if let nickname = customSkuData?.nickname, nickname.isEmpty == false {
                return "\(nickname) (custom SKU)"
            } else {
                return "\(sku) (custom SKU)"
            }
        } else {
            return sku
        }
    }
    
    func getDefaultStoreForCurrentCountry() async -> RetailStore? {
        let stores = await storesForCurrentCountry
        
        let defaultStoreNumber: String
        switch country.locale {
        case "en_US": defaultStoreNumber = "R032"
        case "fr_FR": defaultStoreNumber = "R277"
        case "en_CA": defaultStoreNumber = "R121"
        case "en_AU": defaultStoreNumber = "R238"
        case "de_DE": defaultStoreNumber = "R443"
        case "en_GB": defaultStoreNumber = "R092"
        default:
            return stores.first
        }
        
        return stores.first(where: { $0.storeNumber == defaultStoreNumber }) ?? stores.first
    }
    
    func syncPreferredStore() async {
        if preferredStoreInfoBacking == nil
            || (preferredStoreInfoBacking != nil
                && preferredStoreInfoBacking!.id != preferredStoreNumber
            )
        {
            let stores = await storesForCurrentCountry
            
            preferredStoreInfoBacking = stores.first(where: { $0.id == preferredStoreNumber })
            preferredStoreName = preferredStoreInfoBacking?.name
        }
    }
}

extension Model {
    static var testData: Model {
        let model = Model(isTest: true)
        
        let testParts: [PartAvailability] = [
            PartAvailability(partNumber: "MKGT3LL/A", availability: .available),
            PartAvailability(partNumber: "MKGQ3LL/A", availability: .available),
            PartAvailability(partNumber: "MMQX3LL/A", availability: .available),
        ]
        
        let testStores: [FulfillmentStore] = [
            FulfillmentStore(storeName: "Twenty Ninth St", storeNumber: "R452", city: "Boulder", state: "CO", partsAvailability: testParts),
            FulfillmentStore(storeName: "Flatirons Crossing", storeNumber: "R462", city: "Louisville", state: "CO", partsAvailability: testParts),
            FulfillmentStore(storeName: "Cherry Creek", storeNumber: "R552", city: "Denver", state: "CO", partsAvailability: testParts)
        ]
        
        model.availableParts = testStores.map { ($0, testParts) }
        model.updateErrorState(to: ModelError.noStoresFound)
        
        return model
    }
}
