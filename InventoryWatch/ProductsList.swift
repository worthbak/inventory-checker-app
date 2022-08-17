//
//  ProductsList.swift
//  InventoryWatch
//
//  Created by Worth Baker on 8/7/22.
//

import SwiftUI

struct ProductsList: View {
    @EnvironmentObject var model: Model
    @AppStorage("useLargeText") private var useLargeText: Bool = false
    
    var body: some View {
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
                        
                  let sortedProductNames = data.1.map { model.productName(forSKU: $0.partNumber) }
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
    }
}

struct ProductsList_Previews: PreviewProvider {
    static var previews: some View {
        ProductsList()
    }
}
