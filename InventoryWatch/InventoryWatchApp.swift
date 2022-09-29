//
//  InventoryWatchApp.swift
//  InventoryWatch
//
//  Created by Worth Baker on 11/8/21.
//

import SwiftUI

@main
struct AppVersionSelector {
    static func main() {
        if #available(macOS 13.0, *) {
            InventoryWatchAppMacOS13.main()
        } else {
            InventoryWatchApp.main()
        }
    }
}

@available(macOS 13.0, *)
struct InventoryWatchAppMacOS13: App {
    @StateObject var model = Model()
    @AppStorage("showInMenuBar") private var showInMenuBar: Bool = true
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(model)
        }
        .windowStyle(HiddenTitleBarWindowStyle())
        .commands {
            CommandGroup(replacing: .newItem) {
                Button(action: {
                    model.fetchLatestInventory()
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
        
        MenuBarExtra(isInserted: $showInMenuBar) {
                MenuBarView()
                .frame(maxHeight: 300)
                    .environmentObject(model)
        } label: {
            HStack {
                let total = model.availableParts.reduce(0) { partialResult, part in
                    partialResult + part.1.count
                }
                if let statusBarLogo = statusBarLogo {
                    Image(nsImage: statusBarLogo)
                }
                Text("\(total) in stock")
            }
        }
        .menuBarExtraStyle(.window)
    }
    
    var statusBarLogo: NSImage? {
        let image = NSImage(named: "StatusBarLogo")
        image?.isTemplate = true
        return image
    }
}

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
                    model.fetchLatestInventory()
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
