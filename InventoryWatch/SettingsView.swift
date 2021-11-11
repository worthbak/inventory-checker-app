//
//  SettingsView.swift
//  InventoryWatch
//
//  Created by Worth Baker on 11/9/21.
//

import SwiftUI

struct SettingsView: View {
    private struct ProductModel: Identifiable, Equatable {
        let sku: String
        var name: String
        var isFavorite: Bool
        
        var id: String { sku }
    }
    
    private struct StoreWithSelection: Identifiable, Equatable {
        var store: JsonStore
        var isSelected: Bool
        
        var id: String { store.storeNumber }
        var storeNumber: String { store.storeNumber }
        var storeName: String { store.storeNumber }
        var city: String { store.city }
    }
    
    @EnvironmentObject var model: Model
    
    @AppStorage("preferredCountry") private var preferredCountry = "US"
    @AppStorage("preferredStoreNumber") private var preferredStoreNumber = ""
    @AppStorage("preferredSKUs") private var preferredSKUs: String = ""
    
    @State private var selectedCountryIndex = 0
    @State private var allModels: [ProductModel] = []
    @State private var allStores: [StoreWithSelection] = []
    @State private var storeSearchText: String = ""
    
    @State private var _selectedStore: String = ""
    
    var body: some View {
        VStack(alignment: .leading) {
            Picker("Country", selection: $selectedCountryIndex) {
                ForEach(0..<OrderedCountries.count) { index in
                    let countryCode = OrderedCountries[index]
                    let country = Countries[countryCode]
                    Text(country?.name ?? countryCode)
                }
            }
            .fixedSize()
            .padding()
            
            HStack {
                List {
                    ForEach($allModels) { model in
                        HStack {
                            Toggle("", isOn: model.isFavorite)
                                .toggleStyle(.checkbox)
                            
                            Text(model.name.wrappedValue)
                        }
                    }
                }
                if #available(macOS 12.0, *) {
                    List {
                        TextField("Type here to filter stores", text: $storeSearchText)
                        
                        ForEach($allStores) { store in
                            HStack {
                                Toggle("", isOn: store.isSelected)
                                    .toggleStyle(.checkbox)
                                
                                Text("\(store.store.storeName.wrappedValue), \(store.store.city.wrappedValue)")
                            }
                        }
                    }
                }
            }
            
        }
        .padding()
        .onAppear {
            loadCountries()
            loadSkus()
            loadStores(filterText: nil)
        }
        .onChange(of: selectedCountryIndex) { newValue in
            print(newValue)
            let newCountry = OrderedCountries[newValue]
            preferredCountry = newCountry
        }
        .onChange(of: allModels) { models in
            let favoritedModels = models.filter { $0.isFavorite }
            
            preferredSKUs = favoritedModels
                .map { $0.sku }
                .joined(separator: ",")
        }
        .onChange(of: storeSearchText) { newText in
            guard newText.isEmpty == false else {
                loadStores(filterText: nil)
                return
            }
            
            loadStores(filterText: newText)
        }
        .onChange(of: allStores) { newStores in
            let currentSelected = _selectedStore
            
            for store in newStores {
                if store.isSelected && store.storeNumber != currentSelected {
                    _selectedStore = store.storeNumber
                }
            }
            
            if preferredStoreNumber != _selectedStore {
                preferredStoreNumber = _selectedStore
                model.syncPreferredStore()
            }
            
            loadStores(filterText: storeSearchText)
        }
    }
    
    func loadCountries() {
        OrderedCountries.enumerated().forEach { index, value in
            if value == preferredCountry {
                selectedCountryIndex = index
            }
        }
    }
    
    func loadSkus() {
        let favoriteSkus = Set<String>(preferredSKUs.components(separatedBy: ","))
        
        allModels = model.skuData.orderedSKUs.map { sku in
            let name = model.skuData.productName(forSKU: sku) ?? sku
            return ProductModel(sku: sku, name: name, isFavorite: favoriteSkus.contains(sku))
        }
    }
    
    func loadStores(filterText: String?) {
        if _selectedStore.isEmpty {
            _selectedStore = preferredStoreNumber
        }
        
        let storesJson = model.allStores
        let stores: [StoreWithSelection] = storesJson.map { store in
            StoreWithSelection(
                store: store,
                isSelected: store.storeNumber == _selectedStore
            )
        }
        if let filter = filterText?.lowercased(), filter.isEmpty == false {
            allStores = stores.filter { store in
                return store.storeName.lowercased().contains(filter)
                || store.city.lowercased().contains(filter)
            }
        } else {
            allStores = stores
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
            .environmentObject(Model.testData)
    }
}
