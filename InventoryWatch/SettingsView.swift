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
        
        var id: String { storeNumber }
        var storeNumber: String { store.storeNumber }
        var storeName: String { store.storeName }
        var city: String { store.city }
    }
    
    @EnvironmentObject var model: Model
    
    @AppStorage("preferredCountry") private var preferredCountry = "US"
    @AppStorage("preferredStoreNumber") private var preferredStoreNumber = ""
    @AppStorage("preferredSKUs") private var preferredSKUs: String = ""
    @AppStorage("preferredUpdateInterval") private var preferredUpdateInterval: Int = 1
    @AppStorage("preferredProductType") private var preferredProductType: String = "MacBookPro"
    
    @State private var selectedCountryIndex = 0
    @State private var allModels: [ProductModel] = []
    @State private var allStores: [StoreWithSelection] = []
    @State private var storeSearchText: String = ""
    @State private var selectedStore: String = ""
    
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
            .padding(.leading, 8)
            
            Picker("Product Type", selection: $preferredProductType) {
                Text("MacBook Pro").tag(ProductType.MacBookPro.rawValue)
                Text("iPhone 13").tag(ProductType.iPhoneRegular13.rawValue)
                Text("iPhone 13 mini").tag(ProductType.iPhoneMini13.rawValue)
                Text("iPhone 13 Pro").tag(ProductType.iPhonePro13.rawValue)
                Text("iPhone 13 Pro Max").tag(ProductType.iPhoneProMax13.rawValue)
            }
            .fixedSize()
            .padding(.leading, 8)
            
            Picker("Update every", selection: $preferredUpdateInterval) {
                Text("Never").tag(0)
                Text("1 minute").tag(1)
                Text("5 minutes").tag(5)
                Text("30 minutes").tag(30)
                Text("60 minutes").tag(60)
            }
            .fixedSize()
            .padding(.leading, 8)
            
            HStack {
                VStack(alignment: .leading) {
                    Text("Preferred Model(s)")
                        .font(.headline)
                    
                    List {
                        ForEach($allModels) { model in
                            HStack {
                                Toggle("", isOn: model.isFavorite)
                                    .toggleStyle(.checkbox)
                                
                                Text(model.name.wrappedValue)
                            }
                        }
                    }
                }
                VStack(alignment: .leading) {
                    Text("Preferred Store")
                        .font(.headline)
                    
                    TextField("Type here to filter stores", text: $storeSearchText)
                    
                    List {
                        ForEach($allStores) { store in
                            HStack {
                                Toggle("", isOn: store.isSelected)
                                    .toggleStyle(.checkbox)
                                
                                Text("\(store.store.storeName.wrappedValue), \(store.store.city.wrappedValue)")
                            }
                        }
                    }
                }
            }.padding(.top, 8)
            
        }
        .padding()
        
        .frame(
            minWidth: 500,
            maxWidth: .infinity,
            minHeight: 600,
            maxHeight: .infinity,
            alignment: .center
        )
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
            let currentSelected = selectedStore
            
            for store in newStores {
                if store.isSelected && store.storeNumber != currentSelected {
                    selectedStore = store.storeNumber
                }
            }
            
            if preferredStoreNumber != selectedStore {
                preferredStoreNumber = selectedStore
                model.syncPreferredStore()
            }
            
            loadStores(filterText: storeSearchText)
        }
        .onChange(of: preferredProductType) { newType in
            preferredSKUs = ""
            loadSkus()
            model.clearCurrentAvailableParts()
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
        
        let productType = ProductType(rawValue: preferredProductType) ?? .MacBookPro
        switch productType {
        case .MacBookPro:
            allModels = model.skuData.orderedSKUs.map { sku in
                let name = model.skuData.productName(forSKU: sku) ?? sku
                return ProductModel(sku: sku, name: name, isFavorite: favoriteSkus.contains(sku))
            }
        case .iPhoneRegular13:
            allModels = model.iPhoneModelsUS.regular13.map { model in
                ProductModel(sku: model.sku, name: model.productName, isFavorite: favoriteSkus.contains(model.sku))
            }
        case .iPhoneMini13:
            allModels = model.iPhoneModelsUS.mini13.map { model in
                ProductModel(sku: model.sku, name: model.productName, isFavorite: favoriteSkus.contains(model.sku))
            }
        case .iPhonePro13:
            allModels = model.iPhoneModelsUS.pro13.map { model in
                ProductModel(sku: model.sku, name: model.productName, isFavorite: favoriteSkus.contains(model.sku))
            }
        case .iPhoneProMax13:
            allModels = model.iPhoneModelsUS.proMax13.map { model in
                ProductModel(sku: model.sku, name: model.productName, isFavorite: favoriteSkus.contains(model.sku))
            }
        }
    }
    
    func loadStores(filterText: String?) {
        if selectedStore.isEmpty {
            selectedStore = preferredStoreNumber
        }
        
        let storesJson = model.allStores
        let stores: [StoreWithSelection] = storesJson.map { store in
            StoreWithSelection(
                store: store,
                isSelected: store.storeNumber == selectedStore
            )
        }
        if let filter = filterText?.lowercased(), filter.isEmpty == false {            
            allStores = stores.filter { store in
                if store.storeName.lowercased().contains(filter) {
                    return true
                }
                
                if store.city.lowercased().contains(filter) {
                    return true
                }
                
                if store.storeNumber.lowercased().contains(filter) {
                    return true
                }
                
                return false
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
