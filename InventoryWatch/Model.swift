//
//  Model.swift
//  InventoryWatch
//
//  Created by Worth Baker on 11/8/21.
//

import Foundation

struct Store {
    let storeName: String
    let storeNumber: String
    let city: String
    let state: String
    
    let partsAvailability: [PartAvailability]
}

struct PartAvailability {
    enum PickupAvailability: String {
        case available, unavailable, ineligible
    }
    
    let partNumber: String
    let partName: String // storePickupProductTitle
    let availability: PickupAvailability
}

extension PartAvailability: Identifiable {
    var id: String {
        partNumber
    }
}

final class Model: ObservableObject {
    enum ModelError: Swift.Error {
        case couldNotGenerateURL
        case failedToParseJSON
    }
    
    @Published var availableParts: [PartAvailability] = []
    
    func fetchLatestInventory() throws {
        let urlRoot = "https://www.apple.com/shop/fulfillment-messages?"
        let query = "parts.0=MKGR3LL%2FA&parts.1=MKGP3LL%2FA&parts.2=MKGT3LL%2FA&parts.3=MKGQ3LL%2FA&parts.4=MMQX3LL%2FA&parts.5=MKH53LL%2FA&parts.6=MK1E3LL%2FA&parts.7=MK183LL%2FA&parts.8=MK1F3LL%2FA&parts.9=MK193LL%2FA&parts.10=MK1H3LL%2FA&parts.11=MK1A3LL%2FA&parts.12=MK233LL%2FA&parts.13=MMQW3LL%2FA&parts.14=MYD92LL%2FA&searchNearby=true&store=R172"
        
        guard let url = URL(string: urlRoot + query) else {
            throw ModelError.couldNotGenerateURL
        }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            do {
                try self.parseStoreResponse(data)
            } catch {
                print(error)
            }
        }.resume()
    }
    
    private func parseStoreResponse(_ responseData: Data?) throws {
        guard let responseData = responseData else {
            throw ModelError.couldNotGenerateURL
        }
        
        guard let json = try? JSONSerialization.jsonObject(with: responseData, options: []) as? [String : Any] else {
            throw ModelError.couldNotGenerateURL
        }
        
        guard
            let body = json["body"] as? [String: Any],
                let content = body["content"] as? [String: Any],
                let pickupMessage = content["pickupMessage"] as? [String: Any]
        else {
            throw ModelError.couldNotGenerateURL
        }
        
        guard let storeList = pickupMessage["stores"] as? [[String: Any]] else {
            throw ModelError.couldNotGenerateURL
        }
        
        let collectedStores: [Store] = storeList.compactMap { storeJSON in
            guard let name = storeJSON["storeName"] as? String else { return nil }
            guard let number = storeJSON["storeNumber"] as? String else { return nil }
            guard let state = storeJSON["state"] as? String else { return nil }
            guard let city = storeJSON["city"] as? String else { return nil }
            
            guard let partsAvailability = storeJSON["partsAvailability"] as? [String: [String: Any]] else { return nil }
            let parsedParts: [PartAvailability] = partsAvailability.values.compactMap { part in
                guard let partNumber = part["partNumber"] as? String else { return nil }
                guard let partName = part["storePickupProductTitle"] as? String else { return nil }
                guard
                    let availabilityString = part["pickupDisplay"] as? String,
                        let availability = PartAvailability.PickupAvailability(rawValue: availabilityString)
                else {
                    return nil
                }
                
                return PartAvailability(partNumber: partNumber, partName: partName, availability: availability)
            }
            
            return Store(storeName: name, storeNumber: number, city: city, state: state, partsAvailability: parsedParts)
        }
        
        try self.parseAvailableModels(from: collectedStores)
    }
    
    private func parseAvailableModels(from stores: [Store]) throws {
        let allAvailableModels: [PartAvailability] = stores.flatMap { store in
            return store.partsAvailability.filter { part in
                switch part.availability {
                case .available:
                    return true
                case .unavailable, .ineligible:
                    return false
                }
            }
        }
        
        DispatchQueue.main.async {
            self.availableParts = allAvailableModels
        }
    }
    
}
