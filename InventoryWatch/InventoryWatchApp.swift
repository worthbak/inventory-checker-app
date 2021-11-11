//
//  InventoryWatchApp.swift
//  InventoryWatch
//
//  Created by Worth Baker on 11/8/21.
//

import SwiftUI

@main
struct InventoryWatchApp: App {
    @StateObject var model = Model()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(model)
        }
        .windowStyle(HiddenTitleBarWindowStyle())
        .commands {
            CommandGroup(replacing: .newItem) {
                Button(action: {
                    try! model.fetchLatestInventory()
                }, label: {
                    Text("Reload Inventory")
                })
                    .keyboardShortcut("r", modifiers: .command)
            }
        }
        
        Settings {
            SettingsView()
                .environmentObject(model)
        }
    }
}
