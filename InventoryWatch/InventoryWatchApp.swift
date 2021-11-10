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
        
        Settings {
            SettingsView()
        }
    }
}
