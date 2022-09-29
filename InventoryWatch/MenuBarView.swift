//
//  MenuBarView.swift
//  InventoryWatch
//
//  Created by Ramik Sadana on 09/28/22.
//

import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var model: Model
    
    @AppStorage("lastUpdateDate") private var lastUpdateDate: String = ""
    
    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 5) {
                    if let error = model.errorState {
                        Text(error.errorMessage)
                            .font(.subheadline)
                            .italic()
                            .padding(.bottom)
                    }
                
                VStack(alignment: .leading, spacing: 5) {
                    
                    let storeFont = Font.headline.weight(.semibold)
                    let cityFont = Font.subheadline.weight(.semibold)
                    let productFont = Font.body.weight(.regular)
                    
                    ForEach(model.availableParts, id: \.0.storeNumber) { data in
                        Text("\(Text(data.0.storeName).font(storeFont)) \(Text(data.0.locationDescription).font(cityFont))")
                        
                        let sortedProductNames = data.1.map { model.productName(forSKU: $0.partNumber) }
                            .sortedNumerically()
                        
                        ForEach(sortedProductNames, id: \.self) { productName in
                            Text(productName)
                                .font(productFont)
                        }
                        
                        Divider()
                            .padding(.vertical, 4)
                    }
                }
                
                if model.availableParts.isEmpty && model.isLoading == false {
                    Text("No models available in-store.")
                        .foregroundColor(.secondary)
                }
                
                if lastUpdateDate.isEmpty == false {
                    Text("Last update at \(lastUpdateDate)")
                        .foregroundColor(.secondary)
                        .padding(.bottom)
                }
            }
            .padding(.horizontal, 8)
            .padding(.top)
        }
        .frame(width: 250)
        .background(.black.opacity(0.05))
    }
}

struct MenuBarView_Previews: PreviewProvider {
    static var previews: some View {
        MenuBarView()
            .environmentObject(Model.testData)
    }
}
