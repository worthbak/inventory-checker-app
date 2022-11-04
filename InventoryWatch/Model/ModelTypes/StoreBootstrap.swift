//
//  StoreBootstrap.swift
//  InventoryWatch
//
//  Created by Worth Baker on 10/1/22.
//

import Foundation

struct StoreBootstrap: Decodable {
    
    enum CodingKeys: String, CodingKey {
        case storeListData
    }
    
    let countryData: [String: StoreCountry]
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let storeListData = try container.decode([StoreCountry].self, forKey: .storeListData)
        
        countryData = storeListData.reduce(into: [:], { partialResult, country in
            partialResult[country.locale] = country
        })
    }
}

struct StoreCountry: Decodable {
    enum CodingKeys: String, CodingKey {
        case locale, hasStates, store, state
    }
    
    let locale: String
    let hasStates: Bool
    
    /// `stores` is compiled from the raw JSON `state` array, if the country has states.
    let stores: [RetailStore]
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        locale = try container.decode(String.self, forKey: .locale)
        hasStates = try container.decode(Bool.self, forKey: .hasStates)
        
        let states: [StoreState]
        if hasStates {
            states = try container.decode([StoreState].self, forKey: .state)
        } else {
            let singleStore = try container.decode([RetailStore].self, forKey: .store)
            states = [
                StoreState(name: "", store: singleStore)
            ]
        }
        
        stores = states.reduce(into: [RetailStore](), { partialResult, state in
            partialResult.append(contentsOf: state.store)
        })
        
    }
}

private struct StoreState: Decodable {
    let name: String
    let store: [RetailStore]
}

struct RetailStore: Decodable, Equatable {
    var storeNumber: String { id }
    
    let id: String
    var name: String
    var telephone: String
    var slug: String
    var address: StoreAddress
}

struct StoreAddress: Decodable, Equatable {
    var city: String
    
    let address1: String?
    let address2: String?
    
    let stateName: String?
    let stateCode: String?
    let postalCode: String?
    
    var cityStateDisplay: String {
        let stateText: String
        if let stateCode, !stateCode.isEmpty {
            stateText = ", \(stateCode)"
        } else if let stateName, !stateName.isEmpty {
            stateText = ", \(stateName)"
        } else {
            stateText = ""
        }
        
        return city + stateText
    }
}
