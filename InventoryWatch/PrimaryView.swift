//
//  PrimaryView.swift
//  InventoryWatch
//
//  Created by Worth Baker on 8/7/22.
//

import SwiftUI

struct Fruit: Identifiable {
    let id = UUID().uuidString
    let name: String
}
final class ViewModel: ObservableObject {
    init(fruits: [Fruit] = ViewModel.defaultFruits) {
        self.fruits = fruits
        self.selectedId = fruits[1].id
    }
    @Published var fruits: [Fruit]
    @Published var selectedId: String?
    static let defaultFruits: [Fruit] = ["Apple", "Orange", "Pear"].map({ Fruit(name: $0) })
}

struct PrimaryView: View {
    @StateObject var viewModel = ViewModel()
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 0.0) {
                HStack(alignment: .center) {
                    Text("Products")
                        .font(.headline)
                    
                    Spacer()
                    
                    Button(
                        action: { print("tap!" )},
                        label: { Image(systemName: "plus.circle.fill") }
                    ).buttonStyle(.borderless)
                }
                .padding([.leading, .trailing, .top], 8)
                .padding(.bottom, 4)
                
                List {
                    ForEach(viewModel.fruits) { item in
                        NavigationLink(item.name, tag: item.id, selection: $viewModel.selectedId) {
                            Text(item.name)
                                .navigationTitle(item.name)
                                
                                
                        }
                    }
                }
            }
            .listStyle(.sidebar)
            
            Text("No selection")
        }
    }
}

struct PrimaryView_Previews: PreviewProvider {
    static var previews: some View {
        PrimaryView()
    }
}
