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

struct InventoryWatchApp: App {
    @StateObject var model = ViewModel()
    
    var body: some Scene {
        ContentViewScene(model: model)
        
        SettingsScene(model: model)
    }
}

@available(macOS 13.0, *)
struct InventoryWatchAppMacOS13: App {
    @StateObject var model = ViewModel()
    
    var body: some Scene {
        ContentViewScene(model: model)
        
        SettingsScene(model: model)
        
        MenuBarScene(model: model)
    }
}

struct ContentViewScene: Scene {
    @StateObject var model: ViewModel
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(model)
        }
        .windowStyle(HiddenTitleBarWindowStyle())
        .commands {
            CommandGroup(replacing: .newItem) {
                Button(action: {
                    Task { await model.fetchLatestInventory() }
                }, label: {
                    Text("Reload Inventory")
                })
                .keyboardShortcut("r", modifiers: .command)
            }
        }
    }
}

struct SettingsScene: Scene {
    @StateObject var model: ViewModel
    var body: some Scene {
        Settings {
            SettingsView()
                .environmentObject(model)
        }
    }
}

@available(macOS 13.0, *)
struct MenuBarScene: Scene {
    @StateObject var model: ViewModel
    
    @AppStorage("showInMenuBar") private var showInMenuBar: Bool = true
    
    var body: some Scene {
        MenuBarExtra(isInserted: $showInMenuBar) {
            ProductListView()
                .frame(minWidth: 350, minHeight: 500)
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
