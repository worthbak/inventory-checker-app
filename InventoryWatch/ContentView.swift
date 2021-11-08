//
//  ContentView.swift
//  InventoryWatch
//
//  Created by Worth Baker on 11/8/21.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var model: Model
    
    var body: some View {
        VStack {
            Text("Available Models")
                .padding()
            
            List {
                ForEach(model.availableParts) {
                    Text($0.partName)
                }
            }
            
            Button("Run Query") {
                try! model.fetchLatestInventory()
            }
            .padding()
        }
        .frame(minWidth: 500, maxWidth: .infinity, minHeight: 300, maxHeight: .infinity, alignment: .center)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
