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
    
    @EnvironmentObject var model: Model
    
    @AppStorage("preferredCountry") private var preferredCountry = "US"
    @AppStorage("preferredSKUs") private var preferredSKUs: String = ""
    
    @State private var selectedCountryIndex = 0
    
    @State private var allModels: [ProductModel] = []
    
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
                List($allModels) { model in
                    HStack {
                        Toggle("", isOn: model.isFavorite)
                            .toggleStyle(.checkbox)
                        
                        Text(model.name.wrappedValue)
                    }
                }
                
                List($allModels) { model in
                    HStack {
                        Toggle("", isOn: model.isFavorite)
                            .toggleStyle(.checkbox)
                        
                        Text(model.name.wrappedValue)
                    }
                }
            }
            
        }
        .padding()
        .onAppear {
            loadCountries()
            loadSkus()
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
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
            .environmentObject(Model.testData)
    }
}
