//
//  FulfillmentModel.swift
//  InventoryWatch
//
//  Created by Worth Baker on 10/25/22.
//

import Foundation

actor FulfillmentModel {
    
    enum Error: Swift.Error {
        case invalidProjectState
        case couldNotGenerateURL
        case noStoresFound
    }
    
    enum NetworkError: Swift.Error {
        case storeUnavailable
    }
    
    enum ParsingError: Swift.Error {
        case invalidStoreResponse
        case unexpectedJSONStructure
    }
    
    let defaultsManager = DefaultsVendor()
    let skuDataLoader = SKUDataLoader()
    
    var skuDataForPreferredProduct: SKUData {
        get async throws {
            return try await skuDataLoader.skuDataForPreferredProduct
        }
    }
    
    private var cachedStoreData: [String: StoreCountry] = [:]
    
    private var modelParsingFilter: Set<String>? {
        let filterForPreferredModels = defaultsManager.showResultsOnlyForPreferredModels
        var filterModels = filterForPreferredModels ? defaultsManager.preferredSKUs : nil
        if let customSku = defaultsManager.customSkuData?.sku {
            filterModels?.insert(customSku)
        }
        
        return filterModels
    }
    
    func loadStoresByCountry() async throws -> [String: StoreCountry] {
        if cachedStoreData.isEmpty == false {
            return cachedStoreData
        }
        
        let decoder = JSONDecoder()
        
        do {
            // Try loading remote stores first
            let url = URL(string: "https://www.apple.com/rsp-web/store-list?locale=en_US")!
            let (data, _) = try await URLSession.shared.data(from: url)
            let jsonStores = try decoder.decode(StoreBootstrap.self, from: data)
            
            cachedStoreData = jsonStores.countryData
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
            throw Error.invalidProjectState
        }
    }
    
    func fetchInventory() async throws -> [(FulfillmentStore, [PartAvailability])] {
        let urlRoot = "https://www.apple.com/\(defaultsManager.countryPathElement.lowercased())shop/fulfillment-messages?"
        let query = try await generateQueryString()
        
        guard let url = URL(string: urlRoot + query) else {
            throw Error.couldNotGenerateURL
        }
        
        // Log the URL for debugging
        print(url.absoluteString)
        
        let (data, response) = try await URLSession.shared.data(from: url)
        return try await parseStoreResponse(data, response: response as? HTTPURLResponse, filterForModels: modelParsingFilter)
    }
    
    private func generateQueryString() async throws -> String {
        
        let skuData = try await skuDataLoader.skuDataForPreferredProduct
        
        var allSkus = skuData.orderedSKUs
        if let customSku = defaultsManager.customSkuData?.sku {
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
        
        queryItems.append("searchNearby=\(defaultsManager.shouldIncludeNearbyStores)")
        queryItems.append("store=\(defaultsManager.preferredStoreNumber)")
        
        return queryItems.joined(separator: "&")
    }
    
    private func parseStoreResponse(_ responseData: Data?, response: HTTPURLResponse?, filterForModels: Set<String>?) async throws -> [(FulfillmentStore, [PartAvailability])] {
        guard let responseData = responseData else {
            throw errorForStatusCode(response?.statusCode) ?? ParsingError.invalidStoreResponse
        }
        
        guard let json = try? JSONSerialization.jsonObject(with: responseData, options: []) as? [String : Any] else {
            throw errorForStatusCode(response?.statusCode) ?? ParsingError.invalidStoreResponse
        }
        
        guard
            let body = json["body"] as? [String: Any],
            let content = body["content"] as? [String: Any],
            let pickupMessage = content["pickupMessage"] as? [String: Any]
        else {
            throw ParsingError.unexpectedJSONStructure
        }
        
        guard let storeList = pickupMessage["stores"] as? [[String: Any]] else {
            throw Error.noStoresFound
        }
        
        let skuData = try await skuDataForPreferredProduct
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
                
                // get name from SKU data, or custom SKU if available 
                let productName: String
                if let name = skuData.productName(forSKU: partNumber) {
                    productName = name
                } else if let customSku = defaultsManager.customSkuData, partNumber == customSku.sku {
                    productName = customSku.nickname
                } else {
                    productName = partNumber
                }
                
                return PartAvailability(partNumber: partNumber, partName: productName, availability: availability)
            }
            
            
            
            return FulfillmentStore(storeName: name, storeNumber: number, city: city, state: state, partsAvailability: parsedParts)
        }
        
        return self.parseAvailableModels(from: collectedStores, filterForModels: filterForModels)
    }
    
    private func parseAvailableModels(from stores: [FulfillmentStore], filterForModels: Set<String>?) -> [(FulfillmentStore, [PartAvailability])] {
        let allAvailableModels: [(FulfillmentStore, [PartAvailability])] = stores
            .sorted(by: { first, _ in
                // always put preferred store first
                return first.storeNumber == defaultsManager.preferredStoreNumber
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
        
        return allAvailableModels
    }
    
    private func errorForStatusCode(_ statusCode: Int?) -> FulfillmentModel.NetworkError? {
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
    
}
