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
        var store: RetailStore
        var isSelected: Bool
        
        var id: String { storeNumber }
        var storeNumber: String { store.id }
        var storeName: String { store.name }
        var city: String { store.address.city }
        
        var stateName: String? { store.address.stateName }
        var stateCode: String? { store.address.stateCode }
    }
    
    @EnvironmentObject var model: ViewModel
    @Environment(\.openURL) var openURL
    
    @AppStorage("preferredCountry") private var preferredCountry = "US"
    @AppStorage("preferredStoreNumber") private var preferredStoreNumber = ""
    @AppStorage("preferredSKUs") private var preferredSKUs: String = ""
    @AppStorage("preferredUpdateInterval") private var preferredUpdateInterval: Int = 1
    @AppStorage("preferredProductType") private var preferredProductType: String = "MacBookPro"
    @AppStorage("notifyOnlyForPreferredModels") private var notifyOnlyForPreferredModels: Bool = false
    @AppStorage("showResultsOnlyForPreferredModels") private var showResultsOnlyForPreferredModels: Bool = false
    @AppStorage("customSku") private var customSku = ""
    @AppStorage("customSkuNickname") private var customSkuNickname = ""
    @AppStorage("useLargeText") private var useLargeText: Bool = false
    @AppStorage("shouldIncludeNearbyStores") private var shouldIncludeNearbyStores: Bool = true
    @AppStorage("showInMenuBar") private var showInMenuBar: Bool = true
    
    @State private var selectedCountryIndex = 0
    @State private var allModels: [ProductModel] = []
    @State private var allStores: [StoreWithSelection] = []
    @State private var storeSearchText: String = ""
    @State private var selectedStore: String = ""
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack(alignment: .top, spacing: 24) {
                VStack(alignment: .leading) {
                    Picker("Country", selection: $selectedCountryIndex) {
                        ForEach(0..<OrderedCountries.count, id: \.self) { index in
                            let countryCode = OrderedCountries[index]
                            let country = Countries[countryCode]
                            Text(country?.name ?? countryCode)
                        }
                    }
                    
                    Picker("Product Type", selection: $preferredProductType) {
                        ForEach(ProductCategory.allCases) { category in
                            Divider()
                            ForEach(category.products) { productType in
                                Text(productType.presentableName).tag(productType.rawValue)
                            }
                        }
                        
                    }
                    .onChange(of: preferredProductType) { _ in
                        Task { await model.fetchLatestInventory() }
                    }
                    
                    Picker("Update every", selection: $preferredUpdateInterval) {
                        Text("Never").tag(0)
                        Text("1 minute").tag(1)
                        Text("5 minutes").tag(5)
                        Text("30 minutes").tag(30)
                        Text("60 minutes").tag(60)
                    }
                    
                    Toggle(isOn: $notifyOnlyForPreferredModels) {
                        Text("Notify only for preferred models")
                            .padding(.leading, 4)
                    }
                    Toggle(isOn: $showResultsOnlyForPreferredModels) {
                        Text("Only show results for preferred models")
                            .padding(.leading, 4)
                    }
                    
                    
                }
                .fixedSize()
                .padding(.leading, 8)
                .padding(.bottom, 8)
                
                VStack(alignment: .leading) {
                    HStack(alignment: .top) {
                        Text("Custom SKU")
                        VStack {
                            TextField("Enter a custom SKU", text: $customSku)
                            TextField("Custom SKU Nickname", text: $customSkuNickname)
                        }
                    }
                    
                    Toggle(isOn: $useLargeText) {
                        Text("Use larger text sizes")
                    }
                    
                    Toggle(isOn: $shouldIncludeNearbyStores) {
                        Text("Include results from nearby stores")
                    }
                    
                    Toggle(isOn: $showInMenuBar) {
                        Text("Show InventoryWatch in the Menu Bar")
                    }
                    
                    if model.hasLatestVersion == false {
                        Link(destination: URL(string: "https://worthbak.github.io/inventory-checker-app/")!) {
                            HStack(spacing: 4) {
                                Text("A new version of InventoryWatch is available - click here to download.")
                                Image(systemName: "arrow.forward.circle")
                            }
                            .font(.headline)
                        }
                        .padding(.top, 16)
                    }
                }
            }
            
            HStack {
                VStack(alignment: .leading) {
                    Text("Preferred Model(s)")
                        .font(.headline)
                    
                    Text("Only certain model configurations are stocked in-stores. If you believe a configuration is missing, [please open an issue](https://github.com/worthbak/inventory-checker-app/issues).")
                        .font(.caption).italic()
                    
                    List {
                        ForEach($allModels) { model in
                            Toggle(isOn: model.isFavorite) {
                                Text(model.name.wrappedValue)
                                    .padding(.leading, 4)
                            }
                        }
                    }
                }
                VStack(alignment: .leading) {
                    Text("Preferred Store")
                        .font(.headline)
                    
                    TextField("Filter by store name, city, state, or province", text: $storeSearchText)
                        .padding(.top, -5)
                    
                    List {
                        ForEach($allStores) { store in
                            Toggle(isOn: store.isSelected) {
                                let wrapped = store.wrappedValue
                                Text("\(Text(wrapped.storeName).bold()) - \(wrapped.store.address.cityStateDisplay)")
                                    .padding(.leading, 4)
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
            Task {
                loadCountries()
                await loadSkus()
                await loadStores(filterText: nil)
                await model.fetchLatestGithubRelease()
            }
        }
        .onChange(of: selectedCountryIndex) { newValue in
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
            Task {
                guard newText.isEmpty == false else {
                    await loadStores(filterText: nil)
                    return
                }
                
                await loadStores(filterText: newText)
            }
        }
        .onChange(of: allStores) { newStores in
            Task {
                let currentSelected = selectedStore
                
                for store in newStores {
                    if store.isSelected && store.storeNumber != currentSelected {
                        selectedStore = store.storeNumber
                    }
                }
                
                if preferredStoreNumber != selectedStore {
                    preferredStoreNumber = selectedStore
                }
                
                await loadStores(filterText: storeSearchText)
            }
        }
        .onChange(of: preferredProductType) { newType in
            #warning("TODO: move UserDefaults updates to ViewModel (?)")
            Task {
                preferredSKUs = ""
                await loadSkus()
                model.clearCurrentAvailableParts()
                await model.fetchLatestInventory()
            }
        }
        .onChange(of: preferredStoreNumber) { _ in
            Task {
                await model.updateStoreName()
                await model.fetchLatestInventory()
            }
        }
        .onChange(of: preferredUpdateInterval) { _ in
            Task { await model.fetchLatestInventory() }
        }
        .onChange(of: preferredCountry) { _ in
            Task {
                storeSearchText = ""
                await loadStores(filterText: storeSearchText)
                await loadSkus()
                await selectDefaultStoreForNewCountry()
            }
        }
        .onChange(of: showResultsOnlyForPreferredModels) { _ in
            Task { await model.fetchLatestInventory() }
        }
        .onChange(of: shouldIncludeNearbyStores) { _ in
            Task { await model.fetchLatestInventory() }
        }
    }
    
    func loadCountries() {
        OrderedCountries.enumerated().forEach { index, value in
            if value == preferredCountry {
                selectedCountryIndex = index
            }
        }
    }
    
    func loadSkus() async {
        let favoriteSkus = Set<String>(preferredSKUs.components(separatedBy: ","))
        guard let skuData = try? await model.skuDataForPreferredProduct else {
            return
        }
        
        allModels = skuData.orderedSKUs.map { sku in
            let name = skuData.productName(forSKU: sku) ?? sku
            return ProductModel(sku: sku, name: name, isFavorite: favoriteSkus.contains(sku))
        }
    }
    
    func loadStores(filterText: String?) async {
        if selectedStore.isEmpty {
            selectedStore = preferredStoreNumber
        }
        
        let storesJson = await model.storesForCurrentCountry
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
                
                if (store.stateName?.lowercased() ?? "").contains(filter) {
                    return true
                }
                
                if (store.stateCode?.lowercased() ?? "").contains(filter) {
                    return true
                }
                
                return false
            }
        } else {
            allStores = stores
        }
    }
    
    func selectDefaultStoreForNewCountry() async {
        guard let defaultStore = await model.getDefaultStoreForCurrentCountry() else {
            return
        }
        
        preferredStoreNumber = defaultStore.storeNumber
        selectedStore = preferredStoreNumber
        
        for var store in allStores {
            store.isSelected = store.storeNumber == preferredStoreNumber
        }
    }
}

//struct SettingsView_Previews: PreviewProvider {
//    static var previews: some View {
//        SettingsView()
//            .environmentObject(Model.testData)
//    }
//}
