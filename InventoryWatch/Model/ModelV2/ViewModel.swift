//
//  ViewModel.swift
//  InventoryWatch
//
//  Created by Worth Baker on 10/25/22.
//

import Foundation

@MainActor
final class ViewModel: ObservableObject {
    
    private let fulfillmentModel = FulfillmentModel()
    private let githubModel = GithubModel()
    private let notificationSender = NotificationSender()
    private let defaultsVendor = DefaultsVendor()
    
    @Published var availableParts: [(FulfillmentStore, [PartAvailability])] = []
    @Published var isLoading = false
    @Published var hasLatestVersion = true
    @Published var errorState: ModelError?
    
    @Published var preferredStoreName: String? = nil
    
    private var updateTimer: Timer?
    
    var skuDataForPreferredProduct: SKUData {
        get async throws {
            return try await fulfillmentModel.skuDataForPreferredProduct
        }
    }
    
    var storesForCurrentCountry: [RetailStore] {
        get async {
            let storesByCountry = try? await fulfillmentModel.loadStoresByCountry()
            guard let storesByCountry else {
                print(ModelError.invalidLocalModelStore.localizedDescription)
                return []
            }
            
            guard let stores = storesByCountry[defaultsVendor.preferredCountry.locale]?.stores else {
                // Probably should handle this error state more intelligently
                return []
            }
            
            return stores .sorted(by: { first, second in
                if let firstState = first.address.stateName, let secondState = second.address.stateName {
                    return firstState < secondState
                } else {
                    return first.name < second.name
                }
            })
        }
    }
    
    private var selectedStore: RetailStore? {
        get async {
            let allStores = await storesForCurrentCountry
            let preferredStoreNumber = defaultsVendor.preferredStoreNumber
            
            return allStores.first(where: { $0.storeNumber == preferredStoreNumber })
        }
    }
    
    init() {
        let cancel = defaultsVendor.preferredStoreNumberStream.sink { storeNumber in
            Task {
                let store = await self.storesForCurrentCountry.first(where: { store in
                    store.storeNumber == storeNumber
                })
                
                self.preferredStoreName = store?.name
            }
        }
    }
    
    func fetchLatestInventory() async {
        #warning("todo: timer")
        isLoading = true
        defer { isLoading = false }
        
        #warning("need to implement dupe cancellation")
        do {
            hasLatestVersion = try await githubModel.hasLatestGithubRelease()
            updateErrorState(to: .none, deactivateLoadingState: false)
            
            availableParts = try await fulfillmentModel.fetchInventory()
            updateErrorState(to: .none)
            
            refreshLastUpdateTime()
            
            if let skuData = try? await skuDataForPreferredProduct {
                await notificationSender.sendNotificationIfNeeded(availableParts: availableParts, skuData: skuData)
            }
        } catch {
            #warning("error handling, updates")
            updateErrorState(to: error)
        }
        
        
        
    }
    
    func clearCurrentAvailableParts() {
        availableParts = []
    }
    
    func fetchLatestGithubRelease() async {
        if let latest = try? await githubModel.hasLatestGithubRelease() {
            hasLatestVersion = latest
        }
    }
    
    func updateErrorState(to error: Error?, deactivateLoadingState: Bool = true) {
        if deactivateLoadingState {
            self.isLoading = false
        }
        
        print(error?.localizedDescription ?? "errorState: nil")
        guard let error = error else {
            self.errorState = nil
            return
        }
        
        if let modelError = error as? ModelError {
            self.errorState = modelError
        } else {
            self.errorState = ModelError.generic(error)
        }
    }
    
    func getDefaultStoreForCurrentCountry() async -> RetailStore? {
        let stores = await storesForCurrentCountry
        
        let defaultStoreNumber: String
        switch defaultsVendor.preferredCountry.locale {
        case "en_US": defaultStoreNumber = "R032"
        case "fr_FR": defaultStoreNumber = "R277"
        case "en_CA": defaultStoreNumber = "R121"
        case "en_AU": defaultStoreNumber = "R238"
        case "de_DE": defaultStoreNumber = "R443"
        case "en_GB": defaultStoreNumber = "R092"
        default:
            return stores.first
        }
        
        return stores.first(where: { $0.storeNumber == defaultStoreNumber }) ?? stores.first
    }
    
    private func refreshLastUpdateTime() {
        let df = DateFormatter()
        df.dateFormat = "MMM d, h:mm a"
        let str = df.string(from: Date())
        
        #warning("factor into defaults manager")
        UserDefaults.standard.setValue(str, forKey: "lastUpdateDate")
    }
    
    
    
}
