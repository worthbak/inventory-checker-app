//
//  ContentView.swift
//  InventoryWatch
//
//  Created by Worth Baker on 11/8/21.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var model: ViewModel
    
    @AppStorage("lastUpdateDate") private var lastUpdateDate: String = ""
    @AppStorage("preferredProductType") private var preferredProductType: String = "MacBookPro"
    @AppStorage("useLargeText") private var useLargeText: Bool = false
    @AppStorage("shouldIncludeNearbyStores") private var shouldIncludeNearbyStores: Bool = true
    
    private var onlyShowingPreferredResults: Bool {
        return UserDefaults.standard.bool(forKey: "showResultsOnlyForPreferredModels")
    }
    
    var body: some View {
        VStack {
            HStack {
                ZStack {
                    if model.hasLatestVersion == false {
                        Text("!")
                            .bold().foregroundColor(.blue)
                            .offset(x: 8, y: -8)
                    }
                    Button(
                        action: {
                            if #available(macOS 13, *) {
                                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                            } else {
                                NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
                            }
                        },
                        label: { Image(systemName: "gearshape.fill") }
                    )
                        .buttonStyle(BorderlessButtonStyle())
                        .padding()
                }
                
                Spacer()
                
                VStack {
                    let font = useLargeText ? Font.largeTitle : Font.title2
                    
                    if let product = ProductType(rawValue: preferredProductType) {
                        Text("Available \(Text(product.presentableName).font(font).fontWeight(.heavy)) Models")
                            .font(font)
                            .fontWeight(.semibold)
                    } else {
                        Text("Available Models")
                            .font(font)
                            .fontWeight(.semibold)
                    }
                    
                    
                    if let preferredStoreName = model.preferredStoreName {
                        Text("\(shouldIncludeNearbyStores ? "near" : "at") \(preferredStoreName)")
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
                    
                    let storeFont = useLargeText ? Font.largeTitle.bold() : Font.headline.bold()
                    let cityFont = useLargeText ? Font.title : Font.subheadline.bold()
                    let productFont = useLargeText ? Font.title.weight(.medium) : Font.body.weight(.medium)
                    
                    ForEach(model.availableParts, id: \.0.storeNumber) { data in
                        Text("\(Text(data.0.storeName).font(storeFont)) \(Text(data.0.locationDescription).font(cityFont))")
                        
                        let sortedProductNames = data.1.map { $0.partName }
                            .sortedNumerically()

                      ForEach(sortedProductNames, id: \.self) { productName in
                            Text(productName)
                                .font(productFont)
                        }
                    }
                }
                
                if model.availableParts.isEmpty && model.isLoading == false {
                    Text("No models available in-store.")
                        .foregroundColor(.secondary)
                }
            }
            
            HStack {
                let font = useLargeText ? Font.title3 : Font.caption
                
                if onlyShowingPreferredResults {
                    Text("Only showing results for preferred models.")
                        .font(font)
                        .padding(.leading, 8)
                }
                
                Spacer()
                
                if lastUpdateDate.isEmpty == false {
                    Text("Last update at \(lastUpdateDate)")
                        .font(font)
                } else {
                    Text("")
                        .font(font)
                }
                
                Button(
                    action: { Task { await model.fetchLatestInventory() } },
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
            Task {
                await model.fetchLatestInventory()
                NotificationManager.shared.requestNotificationPermissions()
            }
        }
    }
}

#warning("bring back previews?")
//struct ContentView_Previews: PreviewProvider {
//    static var previews: some View {
//        ContentView()
//            .environmentObject(Model.testData)
//    }
//}
