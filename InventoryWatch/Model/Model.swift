//
//  Model.swift
//  InventoryWatch
//
//  Created by Worth Baker on 11/8/21.
//

import Foundation

#warning("delete")

//@MainActor
//final class Model: ObservableObject {
//
//
//
//
//
//
//    private var cachedPhoneData13: [String: [String: [String: String]]]?
//    private var cachedPhoneData14: [String: [String: [String: String]]]?
//    private var cachedAppleWatchData: [String: [String: [String: String]]]?
//
//
//    private var preferredStoreInfoBacking: RetailStore?
//
//
//
//
//
//
//
//
//    private let isTest: Bool
//
//    init(isTest: Bool = false) {
//        self.isTest = isTest
//    }
//
//    func clearCurrentAvailableParts() {
//        availableParts = []
//    }
//
//
//
//
//
//    #warning("move this to a better spot! and clean up the async code!")
//    private var currentTask: URLSessionDataTask?
//
//    func fetchLatestInventory() async {
//        guard !isTest else {
//            return
//        }
//
//        await syncPreferredStore()
//        isLoading = true
//        currentTask?.cancel()
//
//        self.fetchLatestGithubRelease()
//        self.updateErrorState(to: .none, deactivateLoadingState: false)
//
//        let filterForPreferredModels = UserDefaults.standard.bool(forKey: "showResultsOnlyForPreferredModels")
//        var filterModels = filterForPreferredModels ? preferredSKUs : nil
//        if let customSku = customSkuData?.sku {
//            filterModels?.insert(customSku)
//        }
//
//        let urlRoot = "https://www.apple.com/\(countryPathElement.lowercased())shop/fulfillment-messages?"
//        let query = generateQueryString()
//
//        guard let url = URL(string: urlRoot + query) else {
//            updateErrorState(to: ModelError.couldNotGenerateURL)
//            return
//        }
//
//        // Log the URL for debugging
//        print(url.absoluteString)
//
//        let task = URLSession.shared.dataTask(with: url) { data, response, error in
//
//            Task { @MainActor in self.currentTask = nil }
//
//            if let error = error as? URLError, error.code == .cancelled {
//                print("duplicate URL task cancelled")
//                return
//            }
//
//            do {
//                try self.parseStoreResponse(data, response: response as? HTTPURLResponse, filterForModels: filterModels)
//            } catch {
//                self.updateErrorState(to: error)
//            }
//        }
//
//        currentTask = task
//        task.resume()
//
//        var updateInterval = UserDefaults.standard.integer(forKey: "preferredUpdateInterval")
//        if UserDefaults.standard.object(forKey: "preferredUpdateInterval") == nil {
//            updateInterval = 1
//            UserDefaults.standard.set(updateInterval, forKey: "preferredUpdateInterval")
//        }
//
//        if let existingTimer = updateTimer, existingTimer.timeInterval != Double(updateInterval * 60) {
//            existingTimer.invalidate()
//            updateTimer = nil
//        }
//
//        // Create new update timer if the user-setting is not "Never" (0) and
//        // a timer does not already exist
//        if updateInterval > 0 && updateTimer == nil {
//            let interval = Double(updateInterval * 60)
//            updateTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true, block: { _ in
//                Task { await self.fetchLatestInventory() }
//            })
//        }
//
//        AnalyticsData.updateAnalyticsData()
//    }
//
//
//
//    private func parseStoreResponse(_ responseData: Data?, response: HTTPURLResponse?, filterForModels: Set<String>?) throws {
//        guard let responseData = responseData else {
//            throw errorForStatusCode(response?.statusCode) ?? ModelError.invalidStoreResponse
//        }
//
//        guard let json = try? JSONSerialization.jsonObject(with: responseData, options: []) as? [String : Any] else {
//            throw errorForStatusCode(response?.statusCode) ?? ModelError.invalidStoreResponse
//        }
//
//        guard
//            let body = json["body"] as? [String: Any],
//                let content = body["content"] as? [String: Any],
//                let pickupMessage = content["pickupMessage"] as? [String: Any]
//        else {
//            throw ModelError.unexpectedJSONStructure
//        }
//
//        guard let storeList = pickupMessage["stores"] as? [[String: Any]] else {
//            throw ModelError.noStoresFound
//        }
//
//        let collectedStores: [FulfillmentStore] = storeList.compactMap { storeJSON in
//            guard let name = storeJSON["storeName"] as? String else { return nil }
//            guard let number = storeJSON["storeNumber"] as? String else { return nil }
//            guard let city = storeJSON["city"] as? String else { return nil }
//            let state = storeJSON["state"] as? String
//
//            guard let partsAvailability = storeJSON["partsAvailability"] as? [String: [String: Any]] else { return nil }
//            let parsedParts: [PartAvailability] = partsAvailability.values.compactMap { part in
//                guard let partNumber = part["partNumber"] as? String else { return nil }
//                guard
//                    let availabilityString = part["pickupDisplay"] as? String,
//                    let availability = PartAvailability.PickupAvailability(rawValue: availabilityString)
//                else {
//                    return nil
//                }
//
//                return PartAvailability(partNumber: partNumber, availability: availability)
//            }
//
//            return FulfillmentStore(storeName: name, storeNumber: number, city: city, state: state, partsAvailability: parsedParts)
//        }
//
//        try self.parseAvailableModels(from: collectedStores, filterForModels: filterForModels)
//    }
//
//    private func parseAvailableModels(from stores: [FulfillmentStore], filterForModels: Set<String>?) throws {
//        let allAvailableModels: [(FulfillmentStore, [PartAvailability])] = stores
//            .sorted(by: { first, _ in
//                // always put preferred store first
//                return first.storeNumber == preferredStoreNumber
//            })
//            .compactMap { store in
//                let rv: [PartAvailability] = store.partsAvailability.filter { part in
//                    switch part.availability {
//                    case .available:
//                        if let filter = filterForModels, filter.contains(part.partNumber) == false {
//                            return false
//                        }
//
//                        return true
//                    case .unavailable, .ineligible:
//                        return false
//                    }
//                }
//
//                if rv.isEmpty {
//                    return nil
//                } else {
//                    return (store, rv)
//                }
//        }
//
//        DispatchQueue.main.async {
//            self.availableParts = allAvailableModels
//            self.isLoading = false
//            self.updateErrorState(to: .none)
//
//            let df = DateFormatter()
//            df.dateFormat = "MMM d, h:mm a"
//            let str = df.string(from: Date())
//            UserDefaults.standard.setValue(str, forKey: "lastUpdateDate")
//
//            var hasPreferredModel = false
//            let preferredModels = self.preferredSKUs
//            for model in allAvailableModels {
//                for submodel in model.1 {
//                    if hasPreferredModel == false && preferredModels.contains(submodel.partNumber) {
//                        hasPreferredModel = true
//                        break
//                    }
//
//                    if hasPreferredModel == false, let customSku = self.customSkuData?.sku, submodel.partNumber == customSku {
//                        hasPreferredModel = true
//                        break
//                    }
//                }
//            }
//
//            if !self.isTest {
//                if UserDefaults.standard.bool(forKey: "notifyOnlyForPreferredModels") && !hasPreferredModel {
//                    return
//                }
//
//                let message = self.generateNotificationText(from: allAvailableModels)
//                NotificationManager.shared.sendNotification(title: hasPreferredModel ? "Preferred Model Found!" : "Apple Store Inventory", body: message)
//            }
//        }
//    }
//
//    private func generateNotificationText(from data: [(FulfillmentStore, [PartAvailability])]) -> String {
//        guard data.isEmpty == false else {
//            return "No Inventory Found"
//        }
//
//        var collector: [String: Int] = [:]
//        for (_, parts) in data {
//            for part in parts {
//                collector[part.partNumber, default: 0] += 1
//            }
//        }
//
//        let combined: [String] = collector.reduce(into: []) { partialResult, next in
//            let (key, value) = next
//            let name = skuData.productName(forSKU: key) ?? key
//            partialResult.append("\(name): \(value) found")
//        }
//
//        return combined.joined(separator: ", ")
//    }
//
//    func productName(forSKU sku: String) -> String {
//        if let name = skuData.productName(forSKU: sku) {
//            return name
//        } else if let custom = customSkuData?.sku, custom == sku {
//            if let nickname = customSkuData?.nickname, nickname.isEmpty == false {
//                return "\(nickname) (custom SKU)"
//            } else {
//                return "\(sku) (custom SKU)"
//            }
//        } else {
//            return sku
//        }
//    }
    
//    func getDefaultStoreForCurrentCountry() async -> RetailStore? {
//        let stores = await storesForCurrentCountry
//
//        let defaultStoreNumber: String
//        switch country.locale {
//        case "en_US": defaultStoreNumber = "R032"
//        case "fr_FR": defaultStoreNumber = "R277"
//        case "en_CA": defaultStoreNumber = "R121"
//        case "en_AU": defaultStoreNumber = "R238"
//        case "de_DE": defaultStoreNumber = "R443"
//        case "en_GB": defaultStoreNumber = "R092"
//        default:
//            return stores.first
//        }
//
//        return stores.first(where: { $0.storeNumber == defaultStoreNumber }) ?? stores.first
//    }
    
//    func syncPreferredStore() async {
//        if preferredStoreInfoBacking == nil
//            || (preferredStoreInfoBacking != nil
//                && preferredStoreInfoBacking!.id != preferredStoreNumber
//            )
//        {
//            let stores = await storesForCurrentCountry
//
//            preferredStoreInfoBacking = stores.first(where: { $0.id == preferredStoreNumber })
//            preferredStoreName = preferredStoreInfoBacking?.name
//        }
//    }
//}

//extension Model {
//    static var testData: Model {
//        let model = Model(isTest: true)
//
//        let testParts: [PartAvailability] = [
//            PartAvailability(partNumber: "MKGT3LL/A", availability: .available),
//            PartAvailability(partNumber: "MKGQ3LL/A", availability: .available),
//            PartAvailability(partNumber: "MMQX3LL/A", availability: .available),
//        ]
//
//        let testStores: [FulfillmentStore] = [
//            FulfillmentStore(storeName: "Twenty Ninth St", storeNumber: "R452", city: "Boulder", state: "CO", partsAvailability: testParts),
//            FulfillmentStore(storeName: "Flatirons Crossing", storeNumber: "R462", city: "Louisville", state: "CO", partsAvailability: testParts),
//            FulfillmentStore(storeName: "Cherry Creek", storeNumber: "R552", city: "Denver", state: "CO", partsAvailability: testParts)
//        ]
//
//        model.availableParts = testStores.map { ($0, testParts) }
//        model.updateErrorState(to: ModelError.noStoresFound)
//
//        return model
//    }
//}
