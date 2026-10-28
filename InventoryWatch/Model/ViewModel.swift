//
//  ViewModel.swift
//  InventoryWatch
//
//  Created by Worth Baker on 10/25/22.
//

import Foundation

struct SearchInventoryResult: Identifiable {
    let search: SearchConfiguration
    let availableParts: [(FulfillmentStore, [PartAvailability])]

    var id: UUID { search.id }
}

private struct AvailabilityIdentity: Hashable {
    let countryCode: String
    let storeNumber: String
    let partNumber: String
}

@MainActor
final class ViewModel: ObservableObject {
    
    private let fulfillmentModel: FulfillmentModel
    private let notificationSender = NotificationSender()
    let defaultsVendor = DefaultsVendor()
    
    private var updateTimer: Timer?
    
    @Published var searchResults: [SearchInventoryResult] = []
    @Published var isLoading = false
    @Published var errorState: AppError?
    @Published var pickupErrorKeys: [String] = []
    @Published private(set) var searchConfigurations: [SearchConfiguration] = []
    private var searchConfigurationLoadError: Error?
    
    var skuDataForPreferredProduct: SKUData {
        get async throws {
            return try await fulfillmentModel.skuDataForPreferredProduct
        }
    }
    
    init(fulfillmentModel: FulfillmentModel = FulfillmentModel()) {
        self.fulfillmentModel = fulfillmentModel
        if let savedConfigurations = UserDefaults.standard.data(forKey: "searchConfigurations") {
            do {
                let decoded = try JSONDecoder().decode([SearchConfiguration].self, from: savedConfigurations)
                var seen = Set<UUID>()
                searchConfigurations = decoded.filter { seen.insert($0.id).inserted }
                persistSearchConfigurations()
            } catch {
                searchConfigurationLoadError = error
                errorState = .generic(error)
            }
        } else if let legacyConfiguration = Self.legacySearchConfiguration {
            searchConfigurations = [legacyConfiguration]
            persistSearchConfigurations()
        }

    }

    private static var legacySearchConfiguration: SearchConfiguration? {
        let defaults = DefaultsVendor()
        let family = defaults.preferredProductFamily
        let token: String
        switch family {
        case .watch: token = defaults.preferredWatchToken
        case .iphone: token = defaults.preferredPhoneToken
        case .mac: token = defaults.preferredMacToken
        case .ipad: token = defaults.preferrediPadToken
        case .airpods: token = defaults.preferredAirPodsToken
        case .homepod: token = defaults.preferredHomePodToken
        case .avp: token = defaults.preferredAVPToken
        }
        guard token.isEmpty == false else { return nil }
        return SearchConfiguration(
            family: family,
            token: token,
            countryCode: defaults.preferredCountry.shortcode,
            storeNumber: defaults.preferredStoreNumber
        )
    }

    func addSearchConfiguration(_ configuration: SearchConfiguration) {
        guard searchConfigurations.contains(where: { $0.id == configuration.id }) == false else { return }
        searchConfigurations.append(configuration)
        persistSearchConfigurations()
        clearSearchResults()
        Task { await fetchLatestInventory() }
    }

    func updateSearchConfiguration(_ configuration: SearchConfiguration) {
        guard let index = searchConfigurations.firstIndex(where: { $0.id == configuration.id }),
              searchConfigurations[index] != configuration else { return }
        searchConfigurations[index] = configuration
        persistSearchConfigurations()
        clearSearchResults()
        Task { await fetchLatestInventory() }
    }

    func removeSearchConfiguration(_ configuration: SearchConfiguration) {
        searchConfigurations.removeAll { $0.id == configuration.id }
        persistSearchConfigurations()
        clearSearchResults()
        Task { await fetchLatestInventory() }
    }

    private func persistSearchConfigurations() {
        do {
            let data = try JSONEncoder().encode(searchConfigurations)
            UserDefaults.standard.set(data, forKey: "searchConfigurations")
            searchConfigurationLoadError = nil
        } catch {
            updateErrorState(to: error)
        }
    }

    private var latestTask: Task<(), Never>? = nil
    private var refreshPending = false
    
    func fetchLatestInventory() async {
        if latestTask != nil {
            // Coalesce configuration changes without cancelling a request already on the wire.
            refreshPending = true
            return
        }

        if let searchConfigurationLoadError {
            isLoading = false
            updateErrorState(to: searchConfigurationLoadError)
            return
        }

        guard searchConfigurations.isEmpty == false else {
            searchResults = []
            isLoading = false
            updateErrorState(to: nil)
            return
        }

        isLoading = true
        AnalyticsData.updateAnalyticsData()
        let searches = searchConfigurations
        
        latestTask = Task {
            
            do {
                updateErrorState(to: .none, deactivateLoadingState: false)
                
                let result = try await fulfillmentModel.fetchInventory(searches: searches)
                let pickupErrors = await fulfillmentModel.lastPickupErrorKeys
                try Task.checkCancellation()
                guard searches == searchConfigurations else {
                    finishInventoryFetch()
                    return
                }
                searchResults = result.searchResults
                // Surface any Apple pickup API error keys (e.g., invalidLocalModelStore)
                pickupErrorKeys = pickupErrors
                updateErrorState(to: .none)
                
                refreshLastUpdateTime()
                
                var seenAvailability = Set<AvailabilityIdentity>()
                var hasPreferredModel = false
                var suppressedByPreference = false
                let notificationAvailability = result.searchResults.flatMap { searchResult in
                    let search = searchResult.search
                    let allPartNumbers = searchResult.availableParts.flatMap { $0.1.map(\.partNumber) }
                    let preferred = search.effectivePreferredSKUs(in: allPartNumbers)
                    let customSku = search.customSkuData?.sku
                    return searchResult.availableParts.compactMap { store, parts -> (FulfillmentStore, [PartAvailability])? in
                        let relevantParts = parts.filter { preferred.contains($0.partNumber) || $0.partNumber == customSku }
                        if relevantParts.isEmpty == false { hasPreferredModel = true }
                        let candidateParts: [PartAvailability]
                        if search.notifyOnlyForPreferredModels {
                            if relevantParts.count != parts.count { suppressedByPreference = true }
                            candidateParts = relevantParts
                        } else {
                            candidateParts = parts
                        }
                        let uniqueParts = candidateParts.filter { part in
                            seenAvailability.insert(AvailabilityIdentity(
                                countryCode: searchResult.search.countryCode,
                                storeNumber: store.storeNumber,
                                partNumber: part.partNumber
                            )).inserted
                        }
                        guard uniqueParts.isEmpty == false else { return nil }
                        return (store, uniqueParts)
                    }
                }
                if notificationAvailability.isEmpty && suppressedByPreference {
                    finishInventoryFetch()
                    return
                }
                await notificationSender.sendNotificationIfNeeded(
                    availableParts: notificationAvailability,
                    hasPreferredModel: hasPreferredModel,
                    skuData: result.skuData,
                    searches: searches
                )
                
                print("successful update at \(defaultsVendor.lastUpdateDate ?? "unknown time")")
            } catch {
                if searches == searchConfigurations {
                    updateErrorState(to: error)
                }
            }

            finishInventoryFetch()
        }
    }

    private func finishInventoryFetch() {
        isLoading = false
        latestTask = nil
        resetTimer()
        if refreshPending {
            refreshPending = false
            Task { await fetchLatestInventory() }
        }
    }
    
    func clearSearchResults() {
        searchResults = []
    }
    
    func updateErrorState(to error: Error?, deactivateLoadingState: Bool = true) {
        if deactivateLoadingState {
            self.isLoading = false
        }
        
        guard let error = error else {
            self.errorState = nil
            return
        }
        
        print(error.localizedDescription)
        if let modelError = error as? AppError {
            self.errorState = modelError
        } else {
            self.errorState = AppError.generic(error)
        }
    }
    
    func stores(for countryCode: String) async -> [RetailStore] {
        do {
            guard let country = Countries[countryCode] else { throw AppError.invalidProjectState }
            let storesByCountry = try await fulfillmentModel.loadStoresByCountry(country: country)
            guard let stores = storesByCountry[country.locale]?.stores else { throw AppError.invalidProjectState }
            return stores.sorted { first, second in
                if let firstState = first.address.stateName, let secondState = second.address.stateName {
                    return firstState < secondState
                }
                return first.name < second.name
            }
        } catch {
            updateErrorState(to: error)
            return []
        }
    }

    private func refreshLastUpdateTime() {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, h:mm a"
        let dateString = formatter.string(from: Date())
        
        defaultsVendor.lastUpdateDate = dateString
    }
    
    private func resetTimer() {
        // if the timer settings have changed, kill the current timer
        if let existingTimer = updateTimer, existingTimer.timeInterval != Double(defaultsVendor.preferredUpdateInterval * 60) {
            existingTimer.invalidate()
            updateTimer = nil
        }
        
        // if no timer exists, and the user wants repeated updates, construct a repeating timer 
        if defaultsVendor.preferredUpdateInterval > 0, updateTimer == nil {
            let interval = Double(defaultsVendor.preferredUpdateInterval * 60)
            updateTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true, block: { _ in
                Task { await self.fetchLatestInventory() }
            })
        }
    }
    
}
