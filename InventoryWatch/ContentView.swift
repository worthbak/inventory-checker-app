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
            HStack {
                // This is dumb but it keeps the title centered
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
                    .opacity(0.0)
                    .scaleEffect(0.5, anchor: .center)
                
                Spacer()
                
                Text("Available Models")
                    .font(.title)
                
                Spacer()
                
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
                    .opacity(model.isLoading ? 1.0 : 0.0)
                    .scaleEffect(0.5, anchor: .center)
                    .padding(.top, 8)
                
            }
            
            List {
                ForEach(model.availableParts, id: \.0.storeNumber) { data in
                    Text(data.0.storeName)
                        .font(.headline)
                    
                    ForEach(data.1) {
                        Text($0.descriptiveName ?? $0.partName)
                            .font(.subheadline)
                    }
                }
            }
            
            Button("Run Query") {
                try! model.fetchLatestInventory()
            }
            .padding()
        }
        .frame(
            minWidth: 500,
            maxWidth: .infinity,
            minHeight: 300,
            maxHeight: .infinity,
            alignment: .center
        )
        .onAppear {
            try! model.fetchLatestInventory()
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
