//
//  InventoryWatchApp.swift
//  InventoryWatch
//
//  Created by Worth Baker on 11/8/21.
//

import SwiftUI
import Sparkle
import Combine

enum UpdateChannel: String, CaseIterable, Identifiable {
    case stable
    case beta

    var id: String { rawValue }
}

@MainActor
final class AppUpdater: NSObject, ObservableObject, SPUUpdaterDelegate {
    private var controller: SPUStandardUpdaterController?
    @Published private(set) var selectedChannel: UpdateChannel
    @Published private(set) var canCheckForUpdates = false
    private var updaterAvailabilityObservation: AnyCancellable?

    override init() {
        let savedChannel = UserDefaults.standard.string(forKey: "sparkleUpdateChannel")
        selectedChannel = savedChannel.flatMap(UpdateChannel.init(rawValue:)) ?? .stable
        super.init()

        let info = Bundle.main.infoDictionary
        guard let feedURL = info?["SUFeedURL"] as? String,
              let parsedFeedURL = URL(string: feedURL),
              parsedFeedURL.scheme == "https",
              parsedFeedURL.host != nil,
              let publicKey = info?["SUPublicEDKey"] as? String,
              Data(base64Encoded: publicKey)?.count == 32 else {
            return
        }

        let controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: self,
            userDriverDelegate: nil
        )
        controller.updater.automaticallyChecksForUpdates = true
        controller.updater.updateCheckInterval = 86_400
        canCheckForUpdates = controller.updater.canCheckForUpdates
        updaterAvailabilityObservation = controller.updater
            .publisher(for: \.canCheckForUpdates)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] canCheck in
                self?.canCheckForUpdates = canCheck
            }
        self.controller = controller
    }

    func allowedChannels(for updater: SPUUpdater) -> Set<String> {
        selectedChannel == .beta ? ["beta"] : []
    }

    func checkForUpdates() {
        controller?.checkForUpdates(nil)
    }

    func selectChannel(_ channel: UpdateChannel) {
        guard selectedChannel != channel else { return }
        selectedChannel = channel
        UserDefaults.standard.set(channel.rawValue, forKey: "sparkleUpdateChannel")
        controller?.updater.resetUpdateCycleAfterShortDelay()
    }

    func channelBinding(for channel: UpdateChannel) -> Binding<Bool> {
        Binding(
            get: { self.selectedChannel == channel },
            set: { isSelected in
                if isSelected {
                    self.selectChannel(channel)
                }
            }
        )
    }
}

@main
struct InventoryWatchApp: App {
    @StateObject var model = ViewModel()
    @StateObject private var updater = AppUpdater()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(model)
                .environmentObject(updater)
        }
        .windowStyle(HiddenTitleBarWindowStyle())
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Check for Updates…") {
                    updater.checkForUpdates()
                }
                .disabled(!updater.canCheckForUpdates)

                Menu("Update Channel") {
                    Toggle("Stable", isOn: updater.channelBinding(for: .stable))
                    Toggle("Beta", isOn: updater.channelBinding(for: .beta))
                }
            }
            CommandGroup(replacing: .newItem) {
                Button(action: {
                    Task { await model.fetchLatestInventory() }
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
