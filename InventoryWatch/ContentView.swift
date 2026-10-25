//
//  ContentView.swift
//  InventoryWatch
//
//  Created by Worth Baker on 11/8/21.
//

import SwiftUI

@MainActor
struct ContentView: View {
    @EnvironmentObject var model: ViewModel

    @AppStorage("lastUpdateDate") private var lastUpdateDate: String = ""
    @AppStorage("useLargeText") private var useLargeText: Bool = false
    @AppStorage("shouldIncludeNearbyStores") private var shouldIncludeNearbyStores: Bool = true
    @State private var storesByCountry: [String: [RetailStore]] = [:]

    private var onlyShowingPreferredResults: Bool {
        UserDefaults.standard.bool(forKey: "showResultsOnlyForPreferredModels")
    }

    var body: some View {
        VStack {
            HStack {
                SettingsLink {
                    Image(systemName: "gearshape.fill")
                }
                .padding()

                Spacer()

                VStack {
                    Text("Available Models")
                        .font(useLargeText ? .largeTitle : .title2)
                        .fontWeight(.semibold)

                    if model.searchConfigurations.isEmpty == false {
                        Text("Checking \(model.searchConfigurations.count) \(model.searchConfigurations.count == 1 ? "search" : "searches")")
                            .font(.title2)
                    }
                }

                Spacer()

                ProgressView()
                    .controlSize(.small)
                    .opacity(model.isLoading ? 1 : 0)
                    .scaleEffect(0.5, anchor: .center)
                    .padding(.top, 8)
            }

            ZStack(alignment: .center) {
                List {
                    if let error = model.errorState {
                        Text(error.errorMessage)
                            .font(.subheadline)
                            .italic()
                    }

                    if model.searchConfigurations.isEmpty {
                        Text("Add a product search in Settings to start checking inventory.")
                            .foregroundColor(.secondary)
                    } else {
                        let preferredSkus = Set(
                            (UserDefaults.standard.string(forKey: "preferredSKUs") ?? "")
                                .split(separator: ",")
                                .map(String.init)
                                .filter { !$0.isEmpty }
                        )
                        let displayedPreferredSKUs: Set<String> = onlyShowingPreferredResults ? preferredSkus : []

                        ForEach(model.searchConfigurations) { search in
                            if let country = Countries[search.countryCode] {
                                let result = model.searchResults.first(where: { $0.id == search.id })
                                let availableParts = result?.availableParts ?? []
                                let availableSkus = Set(availableParts.flatMap { $0.1.map(\.partNumber) })
                                let pickupInfo = availableParts.reduce(into: [String: (count: Int, quote: String?)]()) { result, entry in
                                    for part in entry.1 where part.availability == .available {
                                        let current = result[part.partNumber] ?? (0, nil)
                                        result[part.partNumber] = (
                                            current.count + 1,
                                            current.quote ?? part.availabilityStorePickupQuote
                                        )
                                    }
                                }
                                Section("\(searchTitle(for: search, country: country)) · \(country.name)") {
                                    availabilityList(
                                        for: search,
                                        country: country,
                                        availableSkus: availableSkus,
                                        pickupInfo: pickupInfo,
                                        preferredSkus: displayedPreferredSKUs
                                    )
                                    Text(Self.storeLocationLabel(
                                        store: storesByCountry[search.countryCode]?.first { $0.storeNumber == search.storeNumber },
                                        storeNumber: search.storeNumber,
                                        includeNearbyStores: shouldIncludeNearbyStores
                                    ))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            } else {
                                Section(searchTitle(for: search, country: model.defaultsVendor.preferredCountry)) {
                                    Text("The configured country is not available.")
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
            }

            HStack {
                let font = useLargeText ? Font.title3 : Font.caption

                if onlyShowingPreferredResults {
                    Text("Only showing results for preferred models.")
                        .font(font)
                        .padding(.leading, 8)
                }

                Spacer()

                if lastUpdateDate.isEmpty == false {
                    Text("Last update at \(lastUpdateDate)")
                        .font(font)
                }

                Button(
                    action: { Task { await model.fetchLatestInventory() } },
                    label: { Image(systemName: "arrow.clockwise") }
                )
                .buttonStyle(BorderlessButtonStyle())
                .keyboardShortcut("r", modifiers: .command)
                .padding(.trailing, 8)
            }
            .padding(.bottom, 8)
        }
        .frame(
            minWidth: 500,
            maxWidth: .infinity,
            minHeight: 300,
            maxHeight: .infinity,
            alignment: .center
        )
        .onAppear {
            Task {
                await model.fetchLatestInventory()
                NotificationManager.shared.requestNotificationPermissions()
            }
        }
        .task(id: Set(model.searchConfigurations.filter { !$0.storeNumber.isEmpty }.map(\.countryCode))) {
            let countryCodes = Set(model.searchConfigurations.filter { !$0.storeNumber.isEmpty }.map(\.countryCode))
            for countryCode in countryCodes.sorted() {
                let stores = await model.stores(for: countryCode)
                guard !Task.isCancelled else { return }
                storesByCountry[countryCode] = stores
            }
        }
    }

    static func storeLocationLabel(store: RetailStore?, storeNumber: String, includeNearbyStores: Bool) -> String {
        guard !storeNumber.isEmpty else { return "No store selected" }
        let relation = includeNearbyStores ? "Near" : "At"
        guard let store else { return "\(relation) selected store (\(storeNumber))" }
        let name = store.name.hasPrefix("Apple ") ? store.name : "Apple \(store.name)"
        let location = store.address.cityStateDisplay
        return location.isEmpty ? "\(relation) \(name)" : "\(relation) \(name) — \(location)"
    }

    @ViewBuilder
    private func availabilityList(
        for search: SearchConfiguration,
        country: Country,
        availableSkus: Set<String>,
        pickupInfo: [String: (count: Int, quote: String?)],
        preferredSkus: Set<String>
    ) -> some View {
        let loader = SKUDataLoader()

        switch search.family {
        case .watch:
            ProductAvailabilityList(
                country: country,
                token: search.token,
                emptyTokenMessage: "Select a Watch Model in Settings.",
                skuData: loader.watchSKUData(forToken: search.token, country: country),
                availableSkus: availableSkus,
                pickupInfo: pickupInfo,
                preferredSKUs: preferredSkus,
                productURL: { loader.watchProductURL(for: $0, country: country) },
                categoryURL: { loader.watchCategoryURL(for: country, sourcePage: search.token) },
                showPDPPreview: true
            )
        case .iphone:
            ProductAvailabilityList(
                country: country,
                token: search.token,
                emptyTokenMessage: "Select a Phone Model in Settings.",
                skuData: loader.phoneSKUData(forToken: search.token, country: country),
                availableSkus: availableSkus,
                pickupInfo: pickupInfo,
                preferredSKUs: preferredSkus,
                productURL: { loader.phoneProductURL(for: $0, country: country) },
                categoryURL: { loader.phonePDPBaseURL(for: country, sourcePage: search.token) },
                showPDPPreview: true
            )
        case .mac:
            ProductAvailabilityList(
                country: country,
                token: search.token,
                emptyTokenMessage: "Select a Mac Model in Settings.",
                skuData: loader.macSKUData(forToken: search.token, country: country),
                availableSkus: availableSkus,
                pickupInfo: pickupInfo,
                preferredSKUs: preferredSkus,
                productURL: { _ in nil },
                categoryURL: { JSONCatalogMac.pdpBaseURL(for: country, sourcePage: search.token) },
                showPDPPreview: false
            )
        case .ipad:
            ProductAvailabilityList(
                country: country,
                token: search.token,
                emptyTokenMessage: "Select an iPad Model in Settings.",
                skuData: loader.ipadSKUData(forToken: search.token, country: country),
                availableSkus: availableSkus,
                pickupInfo: pickupInfo,
                preferredSKUs: preferredSkus,
                productURL: { _ in nil },
                categoryURL: { JSONCatalogiPad.pdpBaseURL(for: country, sourcePage: search.token) },
                showPDPPreview: false
            )
        case .airpods:
            ProductAvailabilityList(
                country: country,
                token: search.token,
                emptyTokenMessage: "Select an AirPods Model in Settings.",
                skuData: loader.airpodsSKUData(forToken: search.token, country: country),
                availableSkus: availableSkus,
                pickupInfo: pickupInfo,
                preferredSKUs: preferredSkus,
                productURL: { _ in nil },
                categoryURL: { JSONCatalogAirPods.pdpBaseURL(for: country, sourcePage: search.token) },
                showPDPPreview: false
            )
        case .homepod:
            ProductAvailabilityList(
                country: country,
                token: search.token,
                emptyTokenMessage: "Select a HomePod Model in Settings.",
                skuData: loader.homepodSKUData(forToken: search.token, country: country),
                availableSkus: availableSkus,
                pickupInfo: pickupInfo,
                preferredSKUs: preferredSkus,
                productURL: { _ in nil },
                categoryURL: { JSONCatalogHomePod.pdpBaseURL(for: country, sourcePage: search.token) },
                showPDPPreview: false
            )
        case .avp:
            ProductAvailabilityList(
                country: country,
                token: search.token,
                emptyTokenMessage: "Select an Apple Vision Pro Model in Settings.",
                skuData: loader.avpSKUData(forToken: search.token, country: country),
                availableSkus: availableSkus,
                pickupInfo: pickupInfo,
                preferredSKUs: preferredSkus,
                productURL: { _ in nil },
                categoryURL: { JSONCatalogAVP.pdpBaseURL(for: country, sourcePage: search.token) },
                showPDPPreview: false
            )
        }
    }

    private func searchTitle(for search: SearchConfiguration, country: Country) -> String {
        let name: String?
        switch search.family {
        case .watch:
            name = JSONCatalogAppleWatch.tokenDisplayName(for: country, sourcePage: search.token)
        case .iphone:
            name = displayNameForPhoneToken(token: search.token, country: country)
        case .mac:
            name = displayNameForMacToken(token: search.token, country: country)
        case .ipad:
            name = displayNameForiPadToken(token: search.token, country: country)
        case .airpods:
            name = displayNameForAirPodsToken(token: search.token, country: country)
        case .homepod:
            name = displayNameForHomePodToken(token: search.token, country: country)
        case .avp:
            name = displayNameForAVPToken(token: search.token, country: country)
        }
        return "\(search.family.displayName) \(name ?? search.token.replacingOccurrences(of: "-", with: " ").capitalized)"
    }
}

@MainActor
private func displayNameForPhoneToken(token: String, country: Country) -> String? {
    if let explicit = JSONCatalogiPhone.tokenDisplayName(for: country, sourcePage: token), explicit.isEmpty == false {
        return explicit
    }
    var baseName = "iPhone"
    if let dict = JSONCatalogiPhone.categoryData(for: country, sourcePage: token),
       let metadata = dict.values.first {
        if let familyName = metadata.familyName, familyName.isEmpty == false, familyName.lowercased() != "unknown" {
            baseName = familyName
        } else if metadata.family.isEmpty == false {
            baseName = metadata.family.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }
    if baseName.lowercased() == "iphone" { baseName = "iPhone" }
    guard token.hasPrefix("iphone-") else { return baseName }
    let variant = String(token.dropFirst("iphone-".count))
        .replacingOccurrences(of: "-", with: " ")
        .capitalized
    return variant.isEmpty ? baseName : "\(baseName) \(variant)"
}

@MainActor
private func displayNameForMacToken(token: String, country: Country) -> String? {
    JSONCatalogMac.tokenDisplayName(for: country, sourcePage: token)
        ?? token.replacingOccurrences(of: "-", with: " ").capitalized
}

@MainActor
private func displayNameForiPadToken(token: String, country: Country) -> String? {
    JSONCatalogiPad.tokenDisplayName(for: country, sourcePage: token)
        ?? token.replacingOccurrences(of: "-", with: " ").capitalized
}

@MainActor
private func displayNameForAirPodsToken(token: String, country: Country) -> String? {
    JSONCatalogAirPods.tokenDisplayName(for: country, sourcePage: token)
        ?? token.replacingOccurrences(of: "-", with: " ").capitalized
}

@MainActor
private func displayNameForHomePodToken(token: String, country: Country) -> String? {
    JSONCatalogHomePod.tokenDisplayName(for: country, sourcePage: token)
        ?? token.replacingOccurrences(of: "-", with: " ").capitalized
}

@MainActor
private func displayNameForAVPToken(token: String, country: Country) -> String? {
    JSONCatalogAVP.tokenDisplayName(for: country, sourcePage: token)
        ?? token.replacingOccurrences(of: "-", with: " ").capitalized
}
