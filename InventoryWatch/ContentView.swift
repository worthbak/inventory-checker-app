//
//  ContentView.swift
//  InventoryWatch
//
//  Created by Worth Baker on 11/8/21.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var model: Model
    
    @AppStorage("lastUpdateDate") private var lastUpdateDate: String = ""
    @AppStorage("preferredProductType") private var preferredProductType: String = "MacBookPro"
    
    private var onlyShowingPreferredResults: Bool {
        return UserDefaults.standard.bool(forKey: "showResultsOnlyForPreferredModels")
    }
    
    var body: some View {
        VStack {
            HStack {
                Button(
                    action: { NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil) },
                    label: { Image(systemName: "gearshape.fill") }
                )
                    .buttonStyle(BorderlessButtonStyle())
                    .padding()
                
                Spacer()
                
                VStack {
                    if let product = ProductType(rawValue: preferredProductType) {
                        Text("Available \(Text(product.presentableName).font(.title2).fontWeight(.heavy)) Models")
                            .font(.title2)
                            .fontWeight(.semibold)
                    } else {
                        Text("Available Models")
                            .font(.title2)
                            .fontWeight(.semibold)
                    }
                    
                    
                    if let preferredStoreInfo = model.preferredStoreInfo {
                        Text("at \(preferredStoreInfo)")
                            .font(.title2)
                    }
                }
                
                Spacer()
                
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
                    .opacity(model.isLoading ? 1.0 : 0.0)
                    .scaleEffect(0.5, anchor: .center)
                    .padding(.top, 8)
                
            }
            
            ZStack(alignment:.center) {
                
                
                List {
                    if let error = model.errorState {
                        Text(error.errorMessage)
                            .font(.subheadline)
                            .italic()
                    }
                    
                    ForEach(model.availableParts, id: \.0.storeNumber) { data in
                        Text("\(Text(data.0.storeName).font(.headline)) \(Text(data.0.locationDescription).font(.subheadline))")
                            
                        
                        ForEach(data.1) { part in
                            Text(model.productName(forSKU: part.partNumber))
                                .font(.subheadline)
                        }
                    }
                }
                
                if model.availableParts.isEmpty && model.isLoading == false {
                    
                    Text("No models available.")
                        .foregroundColor(.secondary)
                }
            }
            
            HStack {
                if onlyShowingPreferredResults {
                    Text("Only showing results for preferred models.")
                        .font(.caption)
                        .padding(.leading, 8)
                }
                
                Spacer()
                if lastUpdateDate.isEmpty == false {
                    Text("Last update at \(lastUpdateDate)")
                        .font(.caption)
                } else {
                    Text("")
                        .font(.caption)
                }
                
                Button(
                    action: { model.fetchLatestInventory() },
                    label: { Image(systemName: "arrow.clockwise") }
                )
                    .buttonStyle(BorderlessButtonStyle())
                    .keyboardShortcut("r", modifiers: .command)
                    .padding(.trailing, 8)
            }
            .padding(.bottom, 8)
            
        }
        .frame(
            minWidth: 500,
            maxWidth: .infinity,
            minHeight: 300,
            maxHeight: .infinity,
            alignment: .center
        )
        .onAppear {
            model.fetchLatestInventory()
            NotificationManager.shared.requestNotificationPermissions()
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(Model.testData)
    }
}
