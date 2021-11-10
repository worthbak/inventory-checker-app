//
//  SettingsView.swift
//  InventoryWatch
//
//  Created by Worth Baker on 11/9/21.
//

import SwiftUI

struct SettingsView: View {
    @AppStorage("preferredCountry") private var preferredCountry = "US"
    @AppStorage("preferredSKUs") private var preferredSKUs: String = ""
    
    @State private var selectedCountryIndex = 0
    @State var selectedSKUs = Set<String>()
    
    var skuData: [String] {
        OrderedSKUs.map { SKUs[$0]! }
    }
    
    private let countries = [
        "US", "CA"
    ]
    
    var body: some View {
        VStack(alignment: .leading) {
            Picker("Country", selection: $selectedCountryIndex) {
                ForEach(0..<countries.count) {
                    Text(self.countries[$0])
                }
            }
            .fixedSize()
            .padding()
            
            List(skuData, id: \.self, selection: $selectedSKUs) { name in
                Text(name)
            }
            
        }
        .padding()
        .onAppear {
            countries.enumerated().forEach { index, value in
                if value == preferredCountry {
                    selectedCountryIndex = index
                }
            }
            
            let models = preferredSKUs.components(separatedBy: ",")
            for model in models {
                guard !model.isEmpty else {
                    continue
                }
                selectedSKUs.insert(SKUs[model]!)
            }
        }
        .onChange(of: selectedCountryIndex) { newValue in
            let newCountry = countries[newValue]
            preferredCountry = newCountry
        }
        .onChange(of: selectedSKUs) { newValue in
            let thing: [String] = newValue.compactMap { item in
                for (model, name) in SKUs {
                    if name == item {
                        return model
                    } else {
                        continue
                    }
                }
                
                return nil
            }
            
            preferredSKUs = thing.joined(separator: ",")
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
