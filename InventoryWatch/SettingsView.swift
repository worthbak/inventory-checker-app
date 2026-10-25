//
//  SettingsView.swift
//  InventoryWatch
//
//  Created by Worth Baker on 11/9/21.
//

import SwiftUI
import Foundation

struct SettingsView: View {
    
    
    private struct ProductModel: Identifiable, Equatable {
        let sku: String
        var name: String
        var isFavorite: Bool
        
        var id: String { sku }
    }

    // Strip capacity and common color suffixes from any incoming iPhone model title
    private func sanitizeModelTitle(_ title: String) -> String {
        var s = title
        // Remove capacity and anything after it (e.g., " 256GB Black")
        if let re = try? NSRegularExpression(pattern: "(?i)\\s[0-9]{2,4}\\s?(?:GB|TB).*", options: []) {
            let range = NSRange(location: 0, length: (s as NSString).length)
            s = re.stringByReplacingMatches(in: s, options: [], range: range, withTemplate: "")
        }
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private struct StoreWithSelection: Identifiable, Equatable {
        var store: RetailStore
        var isSelected: Bool
        
        var id: String { storeNumber }
        var storeNumber: String { store.id }
        var storeName: String { store.name }
        var city: String { store.address.city }
        
        var stateName: String? { store.address.stateName }
        var stateCode: String? { store.address.stateCode }
    }
    
    @EnvironmentObject var model: ViewModel
    
    @State private var preferredCountry = "US"
    @State private var preferredStoreNumber = ""
    @AppStorage("preferredSKUs") private var preferredSKUs: String = ""
    @AppStorage("preferredUpdateInterval") private var preferredUpdateInterval: Int = 1
    @AppStorage("preferredProductType") private var preferredProductType: String = ProductFamily.iphone.rawValue
    @AppStorage("preferredWatchToken") private var preferredWatchToken: String = ""
    @AppStorage("preferredPhoneToken") private var preferredPhoneToken: String = ""
    @AppStorage("preferredMacToken") private var preferredMacToken: String = ""
    @AppStorage("preferrediPadToken") private var preferrediPadToken: String = ""
    @AppStorage("preferredAirPodsToken") private var preferredAirPodsToken: String = ""
    @AppStorage("preferredHomePodToken") private var preferredHomePodToken: String = ""
    @AppStorage("preferredAVPToken") private var preferredAVPToken: String = ""
    @AppStorage("notifyOnlyForPreferredModels") private var notifyOnlyForPreferredModels: Bool = false
    @AppStorage("showResultsOnlyForPreferredModels") private var showResultsOnlyForPreferredModels: Bool = false
    @AppStorage("customSku") private var customSku = ""
    @AppStorage("customSkuNickname") private var customSkuNickname = ""
    @AppStorage("useLargeText") private var useLargeText: Bool = false
    @AppStorage("shouldIncludeNearbyStores") private var shouldIncludeNearbyStores: Bool = true
    
    @State private var selectedCountryIndex = 0
    @State private var selectedSearchID: UUID?
    @State private var isLoadingSearchConfiguration = false
    @State private var searchLoadGeneration = 0
    @State private var allModels: [ProductModel] = []
    @State private var allStores: [StoreWithSelection] = []
    @State private var storeSearchText: String = ""
    @State private var selectedStore: String = ""
    @State private var availableWatchTokens: [String] = []
    @State private var availablePhoneTokens: [String] = []
    @State private var availableMacTokens: [String] = []
    @State private var watchTokenNames: [String: String] = [:]
    @State private var phoneTokenNames: [String: String] = [:]
@State private var macTokenNames: [String: String] = [:]
    @State private var availableiPadTokens: [String] = []
    @State private var iPadTokenNames: [String: String] = [:]
    @State private var availableAirPodsTokens: [String] = []
    @State private var airpodsTokenNames: [String: String] = [:]
    @State private var availableHomePodTokens: [String] = []
    @State private var homepodTokenNames: [String: String] = [:]
    @State private var availableAVPTokens: [String] = []
    @State private var avpTokenNames: [String: String] = [:]
    
    var body: some View {
        NavigationSplitView {
            searchesSidebar
                .navigationSplitViewColumnWidth(min: 200, ideal: 250)
        } detail: {
            VStack(alignment: .leading) {
                if model.pickupErrorKeys.isEmpty == false {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                        Text("Apple pickup API warning: \(model.pickupErrorKeys.joined(separator: ", "))")
                    }
                    .foregroundColor(.orange)
                    .padding(.bottom, 6)
                }
                if selectedSearchID == nil {
                    ContentUnavailableView(
                        "No Search Selected",
                        systemImage: "magnifyingglass",
                        description: Text("Create a search to monitor a product and store.")
                    )
                } else {
                    VStack(alignment: .leading) {
                        topControls
                        modelsAndStores
                            .padding(.top, 8)
                    }
                    .disabled(isLoadingSearchConfiguration)
                }
            }
            .padding()
        }
        .frame(
            minWidth: 850,
            maxWidth: .infinity,
            minHeight: 600,
            maxHeight: .infinity,
            alignment: .center
        )
        .onAppear { onAppearSetup() }
        .onChange(of: selectedSearchID) { _, newValue in handleSelectedSearchChange(newValue) }
        .onChange(of: selectedCountryIndex) { _, newValue in handleSelectedCountryIndexChange(newValue) }
        .onChange(of: allModels) { _, newValue in handleAllModelsChange(newValue) }
        .onChange(of: storeSearchText) { _, newValue in handleStoreSearchTextChange(newValue) }
        .onChange(of: preferredProductType) { _, newValue in handlePreferredProductTypeChange(newValue) }
        .onChange(of: preferredStoreNumber) { saveSelectedSearch() }
        .onChange(of: preferredUpdateInterval) { handlePreferredUpdateIntervalChange() }
        .onChange(of: preferredCountry) { handlePreferredCountryChange() }
        .onChange(of: showResultsOnlyForPreferredModels) { handleReloadInventory() }
        .onChange(of: shouldIncludeNearbyStores) { handleReloadInventory() }
        .onChange(of: preferredWatchToken) { handlePreferredWatchTokenChange() }
        .onChange(of: preferredPhoneToken) { handlePreferredPhoneTokenChange() }
        .onChange(of: preferredMacToken) { handlePreferredMacTokenChange() }
        .onChange(of: preferrediPadToken) { handlePreferrediPadTokenChange() }
        .onChange(of: preferredAirPodsToken) { handlePreferredAirPodsTokenChange() }
        .onChange(of: preferredHomePodToken) { handlePreferredHomePodTokenChange() }
        .onChange(of: preferredAVPToken) { handlePreferredAVPTokenChange() }
    }

    // Break complex views into smaller computed blocks to assist the type-checker
    @ViewBuilder private var topControls: some View {
        HStack(alignment: .top, spacing: 24) {
            leftControlsView.frame(maxWidth: .infinity, alignment: .leading)
            rightControlsView.frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder private var modelsAndStores: some View {
        HStack(alignment: .top, spacing: 24) {
            preferredStoreList
                .frame(maxWidth: .infinity)
            preferredModelsList
                .frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder private var searchesSidebar: some View {
        VStack(spacing: 0) {
            List(selection: $selectedSearchID) {
                ForEach(model.searchConfigurations) { search in
                    Text(searchDisplayName(search))
                        .lineLimit(2)
                        .tag(search.id)
                        .contextMenu {
                            Button("Delete Search", role: .destructive) {
                                model.removeSearchConfiguration(search)
                                if selectedSearchID == search.id {
                                    selectedSearchID = model.searchConfigurations.first?.id
                                }
                            }
                        }
                }
            }
            HStack {
                Button {
                    createSearch()
                } label: {
                    Label("New Search", systemImage: "plus")
                }
                .disabled(currentSearchConfiguration == nil)
                Spacer()
                if let search = selectedSearch {
                    Button(role: .destructive) {
                        model.removeSearchConfiguration(search)
                        selectedSearchID = model.searchConfigurations.first(where: { $0.id != search.id })?.id
                    } label: {
                        Image(systemName: "trash")
                    }
                    .help("Delete selected search")
                }
            }
            .padding(10)
        }
        .navigationTitle("Searches")
    }

    // MARK: - Extracted subviews
    @ViewBuilder private var leftControlsView: some View {
        VStack(alignment: .leading) {
            countryPickerView
            productOrWatchPickerView

            Picker("Update every", selection: $preferredUpdateInterval) {
                Text("Never").tag(0)
                Text("1 minute").tag(1)
                Text("5 minutes").tag(5)
                Text("30 minutes").tag(30)
                Text("60 minutes").tag(60)
            }
            
            Toggle(isOn: $notifyOnlyForPreferredModels) {
                Text("Notify only for preferred models")
                    .padding(.leading, 4)
            }
            Toggle(isOn: $showResultsOnlyForPreferredModels) {
                Text("Only show results for preferred models")
                    .padding(.leading, 4)
            }
        }
    }

    @ViewBuilder private var rightControlsView: some View {
        VStack(alignment: .leading) {
            HStack(alignment: .top) {
                Text("Custom SKU")
                VStack {
                    TextField("Enter a custom SKU", text: $customSku)
                    TextField("Custom SKU Nickname", text: $customSkuNickname)
                }
            }
            
            Toggle(isOn: $useLargeText) {
                Text("Use larger text sizes")
            }
            
            Toggle(isOn: $shouldIncludeNearbyStores) {
                Text("Include results from nearby stores")
            }
            
        }
    }

    @ViewBuilder private var preferredModelsList: some View {
        VStack(alignment: .leading) {
            Text("Preferred Models")
                .font(.headline)
            
            Text("Only certain model configurations are stocked in-stores. If you believe a configuration is missing, [please open an issue](https://github.com/worthbak/inventory-checker-app/issues).")
                .font(.caption).italic()
            
            List {
                ForEach($allModels) { model in
                    Toggle(isOn: model.isFavorite) {
                        Text(model.name.wrappedValue)
                            .padding(.leading, 4)
                    }
                }
            }
        }
    }

    @ViewBuilder private var preferredStoreList: some View {
        VStack(alignment: .leading) {
            Text("Store for This Search")
                .font(.headline)
            
            TextField("Filter by store name, city, state, or province", text: $storeSearchText)
                .padding(.top, -5)
            
            List {
                ForEach(allStores) { store in
                    Button {
                        selectedStore = store.storeNumber
                        preferredStoreNumber = store.storeNumber
                        allStores = allStores.map { candidate in
                            var updated = candidate
                            updated.isSelected = candidate.storeNumber == store.storeNumber
                            return updated
                        }
                    } label: {
                        HStack {
                            Image(systemName: store.isSelected ? "largecircle.fill.circle" : "circle")
                                .foregroundColor(store.isSelected ? .accentColor : .secondary)
                            Text("\(Text(store.storeName).bold()) - \(store.store.address.cityStateDisplay)")
                                .padding(.leading, 4)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder private var countryPickerView: some View {
        Picker("Country", selection: $selectedCountryIndex) {
            ForEach(0..<OrderedCountries.count, id: \.self) { index in
                let countryCode = OrderedCountries[index]
                let country = Countries[countryCode]
                Text(country?.name ?? countryCode)
            }
        }
    }

    @ViewBuilder private var productOrWatchPickerView: some View {
        let isWatch: Bool = {
            guard let fam = ProductFamily(rawValue: preferredProductType) else { return false }
            return fam.isWatch
        }()
        let isPhone: Bool = {
            guard let fam = ProductFamily(rawValue: preferredProductType) else { return false }
            return fam.isIPhone
        }()
        let isMac: Bool = {
            guard let fam = ProductFamily(rawValue: preferredProductType) else { return false }
            return fam.isMac
        }()
        let isIPad: Bool = {
            guard let fam = ProductFamily(rawValue: preferredProductType) else { return false }
            return fam.isIPad
        }()
        let isAirPods: Bool = {
            guard let fam = ProductFamily(rawValue: preferredProductType) else { return false }
            return fam.isAirPods
        }()
        let isHomePod: Bool = {
            guard let fam = ProductFamily(rawValue: preferredProductType) else { return false }
            return fam.isHomePod
        }()
        let isAVP: Bool = {
            guard let fam = ProductFamily(rawValue: preferredProductType) else { return false }
            return fam.isAVP
        }()
        // Dropdown to switch between product families
        Picker("Product Type", selection: $preferredProductType) {
            ForEach(ProductFamily.allCases) { family in
                Text(family.displayName).tag(family.rawValue)
            }
        }
        .pickerStyle(.menu)
        .frame(minWidth: 260)
        
        if isWatch {
            Picker("Watch Model", selection: $preferredWatchToken) {
                ForEach(availableWatchTokens, id: \.self) { token in
                    Text(displayName(forToken: token)).tag(token)
                }
            }
        } else if isPhone {
            // Selected token display name beside the picker label
            let selectedDisplayName: String = {
                let raw = phoneTokenNames[preferredPhoneToken] ?? preferredPhoneToken
                return sanitizeModelTitle(raw)
            }()
            HStack {
                Text("Phone Model")
                Spacer()
                Text(selectedDisplayName).foregroundColor(.secondary)
            }
            // PDP base preview resolved from scraped JSON
            if let country = Countries[preferredCountry] ?? Countries[preferredCountry.uppercased()] {
                let pdpBase = SKUDataLoader().phonePDPBaseURL(for: country, sourcePage: preferredPhoneToken)
                HStack(spacing: 8) {
                    Text("PDP Base")
                    Spacer()
                    Text(pdpBase?.absoluteString ?? "—")
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            Picker("", selection: $preferredPhoneToken) {
                ForEach(availablePhoneTokens, id: \.self) { token in
                    let label = sanitizeModelTitle(phoneTokenNames[token] ?? token)
                    Text(label).tag(token)
                }
            }
            .id("phonepicker-\(preferredCountry)-\(preferredProductType)-\(availablePhoneTokens.joined(separator: ","))")
            .pickerStyle(.menu)
            .frame(minWidth: 260) // help AppKit menu measure and update reliably
        } else if isMac {
            let selectedMacDisplayName: String = {
                if let country = Countries[preferredCountry] ?? Countries[preferredCountry.uppercased()],
                   preferredMacToken.isEmpty == false,
                   let name = JSONCatalogMac.tokenDisplayName(for: country, sourcePage: preferredMacToken) {
                    return name
                }
                return macTokenNames[preferredMacToken] ?? preferredMacToken
            }()
            HStack {
                Text("Mac Model")
                Spacer()
                Text(selectedMacDisplayName).foregroundColor(.secondary)
            }
            if let country = Countries[preferredCountry] ?? Countries[preferredCountry.uppercased()] {
                let pdpBase = JSONCatalogMac.pdpBaseURL(for: country, sourcePage: preferredMacToken)
                HStack(spacing: 8) {
                    Text("PDP Base")
                    Spacer()
                    Text(pdpBase?.absoluteString ?? "—")
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            Picker("", selection: $preferredMacToken) {
                ForEach(availableMacTokens, id: \.self) { token in
                    Text(macTokenNames[token] ?? token).tag(token)
                }
            }
            .id("macpicker-\(preferredCountry)-\(preferredProductType)-\(availableMacTokens.joined(separator: ","))")
            .pickerStyle(.menu)
            .frame(minWidth: 260)
        } else if isIPad {
            let selectediPadDisplayName: String = {
                if let country = Countries[preferredCountry] ?? Countries[preferredCountry.uppercased()],
                   preferrediPadToken.isEmpty == false,
                   let name = JSONCatalogiPad.tokenDisplayName(for: country, sourcePage: preferrediPadToken) {
                    return name
                }
                return iPadTokenNames[preferrediPadToken] ?? preferrediPadToken
            }()
            HStack {
                Text("iPad Model")
                Spacer()
                Text(selectediPadDisplayName).foregroundColor(.secondary)
            }
            if let country = Countries[preferredCountry] ?? Countries[preferredCountry.uppercased()] {
                let pdpBase = JSONCatalogiPad.pdpBaseURL(for: country, sourcePage: preferrediPadToken)
                HStack(spacing: 8) {
                    Text("PDP Base")
                    Spacer()
                    Text(pdpBase?.absoluteString ?? "—")
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            Picker("", selection: $preferrediPadToken) {
                ForEach(availableiPadTokens, id: \.self) { token in
                    Text(iPadTokenNames[token] ?? token).tag(token)
                }
            }
            .id("iPadpicker-\(preferredCountry)-\(preferredProductType)-\(availableiPadTokens.joined(separator: ","))")
            .pickerStyle(.menu)
            .frame(minWidth: 260)
        } else if isAirPods {
            let selectedAirPodsDisplayName: String = {
                if let country = Countries[preferredCountry] ?? Countries[preferredCountry.uppercased()],
                   preferredAirPodsToken.isEmpty == false,
                   let name = JSONCatalogAirPods.tokenDisplayName(for: country, sourcePage: preferredAirPodsToken) {
                    return name
                }
                return airpodsTokenNames[preferredAirPodsToken] ?? preferredAirPodsToken
            }()
            HStack {
                Text("AirPods Model")
                Spacer()
                Text(selectedAirPodsDisplayName).foregroundColor(.secondary)
            }
            if let country = Countries[preferredCountry] ?? Countries[preferredCountry.uppercased()] {
                let pdpBase = JSONCatalogAirPods.pdpBaseURL(for: country, sourcePage: preferredAirPodsToken)
                HStack(spacing: 8) {
                    Text("PDP Base")
                    Spacer()
                    Text(pdpBase?.absoluteString ?? "—")
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            Picker("", selection: $preferredAirPodsToken) {
                ForEach(availableAirPodsTokens, id: \.self) { token in
                    Text(airpodsTokenNames[token] ?? token).tag(token)
                }
            }
            .id("airpodspicker-\(preferredCountry)-\(preferredProductType)-\(availableAirPodsTokens.joined(separator: ","))")
            .pickerStyle(.menu)
            .frame(minWidth: 260)
        } else if isHomePod {
            let selectedHomePodDisplayName: String = {
                if let country = Countries[preferredCountry] ?? Countries[preferredCountry.uppercased()],
                   preferredHomePodToken.isEmpty == false,
                   let name = JSONCatalogHomePod.tokenDisplayName(for: country, sourcePage: preferredHomePodToken) {
                    return name
                }
                return homepodTokenNames[preferredHomePodToken] ?? preferredHomePodToken
            }()
            HStack {
                Text("HomePod Model")
                Spacer()
                Text(selectedHomePodDisplayName).foregroundColor(.secondary)
            }
            if let country = Countries[preferredCountry] ?? Countries[preferredCountry.uppercased()] {
                let pdpBase = JSONCatalogHomePod.pdpBaseURL(for: country, sourcePage: preferredHomePodToken)
                HStack(spacing: 8) {
                    Text("PDP Base")
                    Spacer()
                    Text(pdpBase?.absoluteString ?? "—")
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            Picker("", selection: $preferredHomePodToken) {
                ForEach(availableHomePodTokens, id: \.self) { token in
                    Text(homepodTokenNames[token] ?? token).tag(token)
                }
            }
            .id("homepodpicker-\(preferredCountry)-\(preferredProductType)-\(availableHomePodTokens.joined(separator: ","))")
            .pickerStyle(.menu)
            .frame(minWidth: 260)
        } else if isAVP {
            let selectedAVPDisplayName: String = {
                if let country = Countries[preferredCountry] ?? Countries[preferredCountry.uppercased()],
                   preferredAVPToken.isEmpty == false,
                   let name = JSONCatalogAVP.tokenDisplayName(for: country, sourcePage: preferredAVPToken) {
                    return name
                }
                return avpTokenNames[preferredAVPToken] ?? preferredAVPToken
            }()
            HStack {
                Text("Apple Vision Pro Model")
                Spacer()
                Text(selectedAVPDisplayName).foregroundColor(.secondary)
            }
            if let country = Countries[preferredCountry] ?? Countries[preferredCountry.uppercased()] {
                let pdpBase = JSONCatalogAVP.pdpBaseURL(for: country, sourcePage: preferredAVPToken)
                HStack(spacing: 8) {
                    Text("PDP Base")
                    Spacer()
                    Text(pdpBase?.absoluteString ?? "—")
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            Picker("", selection: $preferredAVPToken) {
                ForEach(availableAVPTokens, id: \.self) { token in
                    Text(avpTokenNames[token] ?? token).tag(token)
                }
            }
            .id("avppicker-\(preferredCountry)-\(preferredProductType)-\(availableAVPTokens.joined(separator: ","))")
            .pickerStyle(.menu)
            .frame(minWidth: 260)
        }
    }
    
    func loadCountries() {
        OrderedCountries.enumerated().forEach { index, value in
            if value == preferredCountry {
                selectedCountryIndex = index
            }
        }
    }

    private var currentSearchConfiguration: SearchConfiguration? {
        guard let family = ProductFamily(rawValue: preferredProductType) else { return nil }
        let token: String
        switch family {
        case .watch: token = preferredWatchToken
        case .iphone: token = preferredPhoneToken
        case .mac: token = preferredMacToken
        case .ipad: token = preferrediPadToken
        case .airpods: token = preferredAirPodsToken
        case .homepod: token = preferredHomePodToken
        case .avp: token = preferredAVPToken
        }
        guard token.isEmpty == false else { return nil }
        return SearchConfiguration(
            family: family,
            token: token,
            countryCode: preferredCountry,
            storeNumber: preferredStoreNumber
        )
    }

    private var selectedSearch: SearchConfiguration? {
        model.searchConfigurations.first { $0.id == selectedSearchID }
    }

    private func createSearch() {
        guard let configuration = currentSearchConfiguration else { return }
        model.addSearchConfiguration(configuration)
        selectedSearchID = configuration.id
    }

    private func searchDisplayName(_ search: SearchConfiguration) -> String {
        let tokenName: String
        switch search.family {
        case .watch: tokenName = watchTokenNames[search.token] ?? displayName(forToken: search.token)
        case .iphone: tokenName = phoneTokenNames[search.token] ?? search.token
        case .mac: tokenName = macTokenNames[search.token] ?? search.token
        case .ipad: tokenName = iPadTokenNames[search.token] ?? search.token
        case .airpods: tokenName = airpodsTokenNames[search.token] ?? search.token
        case .homepod: tokenName = homepodTokenNames[search.token] ?? search.token
        case .avp: tokenName = avpTokenNames[search.token] ?? search.token
        }
        let countryName = Countries[search.countryCode]?.name ?? search.countryCode
        return "\(search.family.displayName) · \(tokenName) · \(countryName)"
    }
    
    func loadSkus() async {
        let favoriteSkus = Set<String>(preferredSKUs.components(separatedBy: ","))
        // Resolve the preferred product type
        let family = ProductFamily(rawValue: preferredProductType)
        // When Apple Watch is selected, use the JSON-driven, cached watch helper (synchronous)
        if family?.isWatch == true {
            if let country = Countries[preferredCountry] ?? Countries[preferredCountry.uppercased()],
               preferredWatchToken.isEmpty == false,
               let skuData = SKUDataLoader().watchSKUData(forToken: preferredWatchToken, country: country) {
                // Use labels computed by SKUDataLoader (which already apply token display/familyName + watch metadata)
                allModels = skuData.orderedSKUs.map { sku in
                    let name = skuData.productName(forSKU: sku) ?? sku
                    return ProductModel(sku: sku, name: name, isFavorite: favoriteSkus.contains(sku))
                }
                return
            }
        }
        // When iPhone is selected and a token is chosen, use phone token path
        if family?.isIPhone == true {
            if let country = Countries[preferredCountry] ?? Countries[preferredCountry.uppercased()],
               preferredPhoneToken.isEmpty == false,
               let skuData = SKUDataLoader().phoneSKUData(forToken: preferredPhoneToken, country: country) {
                allModels = skuData.orderedSKUs.map { sku in
                    let name = skuData.productName(forSKU: sku) ?? sku
                    return ProductModel(sku: sku, name: name, isFavorite: favoriteSkus.contains(sku))
                }
                return
            }
        }
        // When Mac is selected and a token is chosen, use Mac token path
        if family?.isMac == true {
            if let country = Countries[preferredCountry] ?? Countries[preferredCountry.uppercased()],
               preferredMacToken.isEmpty == false,
               let skuData = SKUDataLoader().macSKUData(forToken: preferredMacToken, country: country) {
                allModels = skuData.orderedSKUs.map { sku in
                    let name = skuData.productName(forSKU: sku) ?? sku
                    return ProductModel(sku: sku, name: name, isFavorite: favoriteSkus.contains(sku))
                }
                return
            }
        }
        // When iPad is selected and a token is chosen, use iPad token path
        if family?.isIPad == true {
            if let country = Countries[preferredCountry] ?? Countries[preferredCountry.uppercased()],
               preferrediPadToken.isEmpty == false,
               let skuData = SKUDataLoader().ipadSKUData(forToken: preferrediPadToken, country: country) {
                allModels = skuData.orderedSKUs.map { sku in
                    let name = skuData.productName(forSKU: sku) ?? sku
                    return ProductModel(sku: sku, name: name, isFavorite: favoriteSkus.contains(sku))
                }
                return
            }
        }
        // When AirPods is selected and a token is chosen, use AirPods token path
        if family?.isAirPods == true {
            if let country = Countries[preferredCountry] ?? Countries[preferredCountry.uppercased()],
               preferredAirPodsToken.isEmpty == false,
               let skuData = SKUDataLoader().airpodsSKUData(forToken: preferredAirPodsToken, country: country) {
                allModels = skuData.orderedSKUs.map { sku in
                    let name = skuData.productName(forSKU: sku) ?? sku
                    return ProductModel(sku: sku, name: name, isFavorite: favoriteSkus.contains(sku))
                }
                return
            }
        }
        // When HomePod is selected and a token is chosen, use HomePod token path
        if family?.isHomePod == true {
            if let country = Countries[preferredCountry] ?? Countries[preferredCountry.uppercased()],
               preferredHomePodToken.isEmpty == false,
               let skuData = SKUDataLoader().homepodSKUData(forToken: preferredHomePodToken, country: country) {
                allModels = skuData.orderedSKUs.map { sku in
                    let name = skuData.productName(forSKU: sku) ?? sku
                    return ProductModel(sku: sku, name: name, isFavorite: favoriteSkus.contains(sku))
                }
                return
            }
        }
        // When AVP is selected and a token is chosen, use AVP token path
        if family?.isAVP == true {
            if let country = Countries[preferredCountry] ?? Countries[preferredCountry.uppercased()],
               preferredAVPToken.isEmpty == false,
               let skuData = SKUDataLoader().avpSKUData(forToken: preferredAVPToken, country: country) {
                allModels = skuData.orderedSKUs.map { sku in
                    let name = skuData.productName(forSKU: sku) ?? sku
                    return ProductModel(sku: sku, name: name, isFavorite: favoriteSkus.contains(sku))
                }
                return
            }
        }
        // Fallback for non-watch (existing async path)
        guard let skuData = try? await model.skuDataForPreferredProduct else { return }
        allModels = skuData.orderedSKUs.map { sku in
            let name = skuData.productName(forSKU: sku) ?? sku
            return ProductModel(sku: sku, name: name, isFavorite: favoriteSkus.contains(sku))
        }
    }

    @MainActor func loadWatchTokens() async {
        guard let country = Countries[preferredCountry] ?? Countries[preferredCountry.uppercased()] else { return }
        availableWatchTokens = JSONCatalogAppleWatch.categoriesSourcePages(for: country)
        // Build human-friendly names for tokens from JSON metadata
        var names: [String: String] = [:]
        for token in availableWatchTokens {
            // Derive from metadata and token (avoid using scraped token_display to prevent CTA/noise)
            if let dict = JSONCatalogAppleWatch.categoryData(for: country, sourcePage: token),
               let md = dict.values.first {
                var baseName: String? = nil
                if let famName = md.familyName, famName.isEmpty == false, famName.lowercased() != "unknown" {
                    baseName = famName
                } else {
                    let fam = md.family
                    if fam == "apple_watch" {
                        baseName = "Apple Watch"
                    } else if fam.isEmpty == false {
                        baseName = fam.replacingOccurrences(of: "_", with: " ").capitalized
                    }
                }
                var variant: String? = nil
                if token.hasPrefix("apple-watch-") {
                    let suffix = String(token.dropFirst("apple-watch-".count))
                    if suffix.isEmpty == false {
                        var v = suffix.replacingOccurrences(of: "-", with: " ").capitalized
                        // Normalize special cases like SE
                        if v.lowercased().hasPrefix("se") {
                            v = v.replacingOccurrences(of: "Se", with: "SE")
                        }
                        variant = v
                    }
                }
                if let base = baseName { names[token] = variant != nil ? "\(base) \(variant!)" : base }
            }
        }
        watchTokenNames = names
        // If current preferredWatchToken is not in the list, set a sensible default (first token or empty)
        if preferredWatchToken.isEmpty || availableWatchTokens.contains(preferredWatchToken) == false {
            preferredWatchToken = availableWatchTokens.first ?? ""
        }
    }

    @MainActor func loadPhoneTokens() async {
        guard let country = Countries[preferredCountry] ?? Countries[preferredCountry.uppercased()] else { return }
        // Load tokens from JSON catalogs
        let rawTokens = JSONCatalogiPhone.categoriesSourcePages(for: country)
        // Guard against accidental SKU lists by filtering to iphone-* tokens.
        var tokenLike = rawTokens.filter { $0.lowercased().hasPrefix("iphone-") }
        // Fallback: if none found (e.g., only legacy aggregate JSON present), derive tokens from any bundled iPhone JSONs
        if tokenLike.isEmpty {
            let all = JSONCatalogiPhone.loadAll()
            var union: Set<String> = []
            for root in all.values {
                if let cm = root.country_mappings {
                    for (_, map) in cm {
                        if let paths = map.shop_paths {
                            for key in paths.keys where key.lowercased().hasPrefix("iphone-") { union.insert(key) }
                        }
                    }
                }
                if union.isEmpty, let dm = root.discovered_models {
                    for (_, byToken) in dm {
                        for key in byToken.keys where key.lowercased().hasPrefix("iphone-") { union.insert(key) }
                    }
                }
            }
            tokenLike = Array(union).sorted()
        }
        availablePhoneTokens = tokenLike
        var names: [String: String] = [:]
        for token in availablePhoneTokens {
            // 1) Prefer explicit per-country token display from JSON if available
            if let explicit = JSONCatalogiPhone.tokenDisplayName(for: country, sourcePage: token), explicit.isEmpty == false {
                names[token] = sanitizeModelTitle(explicit)
                continue
            }
            // 2) Derive base name from JSON (familyName or family)
            var baseName: String = "iPhone"
            if let dict = JSONCatalogiPhone.categoryData(for: country, sourcePage: token),
               let md = dict.values.first {
                if let famName = md.familyName, famName.isEmpty == false, famName.lowercased() != "unknown" {
                    baseName = famName
                } else {
                    let fam = md.family
                    if fam.isEmpty == false {
                        baseName = fam.replacingOccurrences(of: "_", with: " ").capitalized
                    }
                }
            }
            // Ensure proper casing for iPhone family
            if baseName.lowercased() == "iphone" { baseName = "iPhone" }
            // Derive variant from token suffix (e.g., "iphone-17-pro" -> "17 Pro")
            var variant: String = ""
            if token.lowercased().hasPrefix("iphone-") {
                let suffix = String(token.dropFirst("iphone-".count))
                if suffix.isEmpty == false {
                    variant = suffix.replacingOccurrences(of: "-", with: " ").capitalized
                }
            }
            // Compose final name
            let finalName = variant.isEmpty ? baseName : "\(baseName) \(variant)"
            names[token] = sanitizeModelTitle(finalName)
        }
        phoneTokenNames = names
        // Load any previously-saved per-country token selection
        let perCountryKey = "preferredPhoneToken.\(preferredCountry.uppercased())"
        if let saved = UserDefaults.standard.string(forKey: perCountryKey), availablePhoneTokens.contains(saved) {
            preferredPhoneToken = saved
        } else if preferredPhoneToken.isEmpty || availablePhoneTokens.contains(preferredPhoneToken) == false {
            // Keep selection stable when possible; if current selection is missing, pick first available
            preferredPhoneToken = availablePhoneTokens.first ?? ""
        }
    }

    @MainActor func loadMacTokens() async {
        guard let country = Countries[preferredCountry] ?? Countries[preferredCountry.uppercased()] else { return }
        availableMacTokens = JSONCatalogMac.categoriesSourcePages(for: country)
        var names: [String: String] = [:]
        for token in availableMacTokens {
            // Prefer JSON-provided token display if available
            if let explicit = JSONCatalogMac.tokenDisplayName(for: country, sourcePage: token), explicit.isEmpty == false {
                names[token] = explicit
                continue
            }
            // Fallback: prettify token
            names[token] = token.replacingOccurrences(of: "-", with: " ").capitalized
        }
        macTokenNames = names
        // Per-country persisted selection
        let perCountryKey = "preferredMacToken.\(preferredCountry.uppercased())"
        if let saved = UserDefaults.standard.string(forKey: perCountryKey), availableMacTokens.contains(saved) {
            preferredMacToken = saved
        } else if preferredMacToken.isEmpty || availableMacTokens.contains(preferredMacToken) == false {
            preferredMacToken = availableMacTokens.first ?? ""
        }
    }

    @MainActor func loadiPadTokens() async {
        guard let country = Countries[preferredCountry] ?? Countries[preferredCountry.uppercased()] else { return }
        availableiPadTokens = JSONCatalogiPad.categoriesSourcePages(for: country)
        var names: [String: String] = [:]
        for token in availableiPadTokens {
            if let explicit = JSONCatalogiPad.tokenDisplayName(for: country, sourcePage: token), explicit.isEmpty == false {
                names[token] = explicit
                continue
            }
            names[token] = token.replacingOccurrences(of: "-", with: " ").capitalized
        }
        iPadTokenNames = names
        let perCountryKey = "preferrediPadToken.\(preferredCountry.uppercased())"
        if let saved = UserDefaults.standard.string(forKey: perCountryKey), availableiPadTokens.contains(saved) {
            preferrediPadToken = saved
        } else if preferrediPadToken.isEmpty || availableiPadTokens.contains(preferrediPadToken) == false {
            preferrediPadToken = availableiPadTokens.first ?? ""
        }
    }

    @MainActor func loadAirPodsTokens() async {
        guard let country = Countries[preferredCountry] ?? Countries[preferredCountry.uppercased()] else { return }
        availableAirPodsTokens = JSONCatalogAirPods.categoriesSourcePages(for: country)
        var names: [String: String] = [:]
        for token in availableAirPodsTokens {
            if let explicit = JSONCatalogAirPods.tokenDisplayName(for: country, sourcePage: token), explicit.isEmpty == false {
                names[token] = explicit
                continue
            }
            names[token] = token.replacingOccurrences(of: "-", with: " ").capitalized
        }
        airpodsTokenNames = names
        let perCountryKey = "preferredAirPodsToken.\(preferredCountry.uppercased())"
        if let saved = UserDefaults.standard.string(forKey: perCountryKey), availableAirPodsTokens.contains(saved) {
            preferredAirPodsToken = saved
        } else if preferredAirPodsToken.isEmpty || availableAirPodsTokens.contains(preferredAirPodsToken) == false {
            preferredAirPodsToken = availableAirPodsTokens.first ?? ""
        }
    }

    @MainActor func loadHomePodTokens() async {
        guard let country = Countries[preferredCountry] ?? Countries[preferredCountry.uppercased()] else { return }
        availableHomePodTokens = JSONCatalogHomePod.categoriesSourcePages(for: country)
        var names: [String: String] = [:]
        for token in availableHomePodTokens {
            if let explicit = JSONCatalogHomePod.tokenDisplayName(for: country, sourcePage: token), explicit.isEmpty == false {
                names[token] = explicit
                continue
            }
            names[token] = token.replacingOccurrences(of: "-", with: " ").capitalized
        }
        homepodTokenNames = names
        let perCountryKey = "preferredHomePodToken.\(preferredCountry.uppercased())"
        if let saved = UserDefaults.standard.string(forKey: perCountryKey), availableHomePodTokens.contains(saved) {
            preferredHomePodToken = saved
        } else if preferredHomePodToken.isEmpty || availableHomePodTokens.contains(preferredHomePodToken) == false {
            preferredHomePodToken = availableHomePodTokens.first ?? ""
        }
    }

    @MainActor func loadAVPTokens() async {
        guard let country = Countries[preferredCountry] ?? Countries[preferredCountry.uppercased()] else { return }
        availableAVPTokens = JSONCatalogAVP.categoriesSourcePages(for: country)
        var names: [String: String] = [:]
        for token in availableAVPTokens {
            if let explicit = JSONCatalogAVP.tokenDisplayName(for: country, sourcePage: token), explicit.isEmpty == false {
                names[token] = explicit
                continue
            }
            names[token] = token.replacingOccurrences(of: "-", with: " ").capitalized
        }
        avpTokenNames = names
        let perCountryKey = "preferredAVPToken.\(preferredCountry.uppercased())"
        if let saved = UserDefaults.standard.string(forKey: perCountryKey), availableAVPTokens.contains(saved) {
            preferredAVPToken = saved
        } else if preferredAVPToken.isEmpty || availableAVPTokens.contains(preferredAVPToken) == false {
            preferredAVPToken = availableAVPTokens.first ?? ""
        }
    }

    private func displayName(forToken token: String) -> String {
        if let name = watchTokenNames[token], name.isEmpty == false { return name }
        // Fallback: prettify token string
        return token.replacingOccurrences(of: "-", with: " ").capitalized
    }
    
    func loadStores(
        for countryCode: String,
        filterText: String?,
        searchID: UUID? = nil,
        generation: Int? = nil
    ) async {
        if selectedStore.isEmpty {
            selectedStore = preferredStoreNumber
        }
        
        let storesJson = await model.stores(for: countryCode)
        guard preferredCountry == countryCode,
              searchID == nil || selectedSearchID == searchID,
              generation == nil || searchLoadGeneration == generation else { return }
        let stores: [StoreWithSelection] = storesJson.map { store in
            StoreWithSelection(
                store: store,
                isSelected: store.storeNumber == selectedStore
            )
        }
        if let filter = filterText?.lowercased(), filter.isEmpty == false {            
            allStores = stores.filter { store in
                if store.storeName.lowercased().contains(filter) {
                    return true
                }
                
                if store.city.lowercased().contains(filter) {
                    return true
                }
                
                if store.storeNumber.lowercased().contains(filter) {
                    return true
                }
                
                if (store.stateName?.lowercased() ?? "").contains(filter) {
                    return true
                }
                
                if (store.stateCode?.lowercased() ?? "").contains(filter) {
                    return true
                }
                
                return false
            }
        } else {
            allStores = stores
        }
    }
    
    func selectDefaultStoreForNewCountry() async {
        let countryCode = preferredCountry
        let stores = await model.stores(for: countryCode)
        guard preferredCountry == countryCode else { return }
        guard let defaultStore = stores.first else { return }
        preferredStoreNumber = defaultStore.storeNumber
        selectedStore = preferredStoreNumber
        await loadStores(for: countryCode, filterText: storeSearchText)
    }

    // MARK: - Lifecycle helpers used in view modifiers
    private func onAppearSetup() {
        loadCountries()
        if let firstSearch = model.searchConfigurations.first {
            selectedSearchID = firstSearch.id
        } else {
            preferredCountry = UserDefaults.standard.string(forKey: "preferredCountry") ?? "US"
            preferredStoreNumber = UserDefaults.standard.string(forKey: "preferredStoreNumber") ?? ""
            preferredProductType = model.defaultsVendor.preferredProductFamily.rawValue
            selectedCountryIndex = OrderedCountries.firstIndex(of: preferredCountry) ?? 0
            Task {
                await loadAllTokens()
                await loadSkus()
                await loadStores(for: preferredCountry, filterText: nil)
                if preferredStoreNumber.isEmpty {
                    await selectDefaultStoreForNewCountry()
                }
            }
        }
    }

    private func handleSelectedCountryIndexChange(_ newValue: Int) {
        guard OrderedCountries.indices.contains(newValue) else { return }
        let newCountry = OrderedCountries[newValue]
        if preferredCountry != newCountry {
            preferredCountry = newCountry
        }
    }

    private func handleAllModelsChange(_ models: [ProductModel]) {
        let visibleSKUs = Set(models.map(\.sku))
        let existingFavorites = Set(preferredSKUs.split(separator: ",").map(String.init))
        let favoritedModels = models.filter { $0.isFavorite }
        let retainedFavorites = existingFavorites.subtracting(visibleSKUs)
        preferredSKUs = (retainedFavorites.union(favoritedModels.map(\.sku))).sorted().joined(separator: ",")
    }

    private func handleStoreSearchTextChange(_ newText: String) {
        if newText.isEmpty {
            Task { await loadStores(for: preferredCountry, filterText: nil) }
        } else {
            Task { await loadStores(for: preferredCountry, filterText: newText) }
        }
    }

    private func handlePreferredProductTypeChange(_ newType: String) {
        guard isLoadingSearchConfiguration == false else { return }
        Task {
            await loadSkus()
            saveSelectedSearch()
        }
    }

    private func handlePreferredUpdateIntervalChange() {
        Task { await model.fetchLatestInventory() }
    }

    private func handlePreferredCountryChange() {
        guard isLoadingSearchConfiguration == false else { return }
        guard let search = selectedSearch,
              search.countryCode != preferredCountry else { return }

        let targetCountry = preferredCountry
        searchLoadGeneration += 1
        let generation = searchLoadGeneration
        isLoadingSearchConfiguration = true
        storeSearchText = ""
        preferredStoreNumber = ""
        selectedStore = ""

        Task {
            defer {
                if searchLoadGeneration == generation {
                    isLoadingSearchConfiguration = false
                }
            }

            await loadTokens(for: search.family)
            guard isCurrentCountryChange(searchID: search.id, countryCode: targetCountry, generation: generation) else { return }

            let token = selectedToken(for: search.family)
            let country = Countries[targetCountry]
            guard token.isEmpty == false,
                  availableTokens(for: search.family).contains(token),
                  let country,
                  hasCatalogSKUs(for: search.family, token: token, country: country) else {
                await restoreSearchAfterUnsupportedCountryChange(search, generation: generation)
                return
            }

            let stores = await model.stores(for: targetCountry)
            guard isCurrentCountryChange(searchID: search.id, countryCode: targetCountry, generation: generation) else { return }

            let storeNumber = stores.first?.id ?? ""
            preferredStoreNumber = storeNumber
            selectedStore = storeNumber
            await loadSkus()
            guard isCurrentCountryChange(searchID: search.id, countryCode: targetCountry, generation: generation) else { return }

            model.updateSearchConfiguration(
                SearchConfiguration(
                    id: search.id,
                    family: search.family,
                    token: token,
                    countryCode: targetCountry,
                    storeNumber: storeNumber
                )
            )
        }
    }

    private func isCurrentCountryChange(searchID: UUID, countryCode: String, generation: Int) -> Bool {
        selectedSearchID == searchID
            && preferredCountry == countryCode
            && searchLoadGeneration == generation
    }

    private func restoreSearchAfterUnsupportedCountryChange(_ search: SearchConfiguration, generation: Int) async {
        preferredCountry = search.countryCode
        selectedCountryIndex = OrderedCountries.firstIndex(of: search.countryCode) ?? 0
        preferredProductType = search.family.rawValue
        preferredStoreNumber = search.storeNumber
        selectedStore = search.storeNumber
        await loadTokens(for: search.family)
        guard selectedSearchID == search.id, searchLoadGeneration == generation else { return }
        setDraftToken(search.token, for: search.family)
        await loadSkus()
        guard selectedSearchID == search.id, searchLoadGeneration == generation else { return }
        await loadStores(
            for: search.countryCode,
            filterText: nil,
            searchID: search.id,
            generation: generation
        )
    }

    private func loadTokens(for family: ProductFamily) async {
        switch family {
        case .watch: await loadWatchTokens()
        case .iphone: await loadPhoneTokens()
        case .mac: await loadMacTokens()
        case .ipad: await loadiPadTokens()
        case .airpods: await loadAirPodsTokens()
        case .homepod: await loadHomePodTokens()
        case .avp: await loadAVPTokens()
        }
    }

    private func selectedToken(for family: ProductFamily) -> String {
        switch family {
        case .watch: preferredWatchToken
        case .iphone: preferredPhoneToken
        case .mac: preferredMacToken
        case .ipad: preferrediPadToken
        case .airpods: preferredAirPodsToken
        case .homepod: preferredHomePodToken
        case .avp: preferredAVPToken
        }
    }

    private func availableTokens(for family: ProductFamily) -> [String] {
        switch family {
        case .watch: availableWatchTokens
        case .iphone: availablePhoneTokens
        case .mac: availableMacTokens
        case .ipad: availableiPadTokens
        case .airpods: availableAirPodsTokens
        case .homepod: availableHomePodTokens
        case .avp: availableAVPTokens
        }
    }

    private func hasCatalogSKUs(for family: ProductFamily, token: String, country: Country) -> Bool {
        let loader = SKUDataLoader()
        let skuData: SKUData?
        switch family {
        case .watch: skuData = loader.watchSKUData(forToken: token, country: country)
        case .iphone: skuData = loader.phoneSKUData(forToken: token, country: country)
        case .mac: skuData = loader.macSKUData(forToken: token, country: country)
        case .ipad: skuData = loader.ipadSKUData(forToken: token, country: country)
        case .airpods: skuData = loader.airpodsSKUData(forToken: token, country: country)
        case .homepod: skuData = loader.homepodSKUData(forToken: token, country: country)
        case .avp: skuData = loader.avpSKUData(forToken: token, country: country)
        }
        return skuData?.orderedSKUs.isEmpty == false
    }

    private func handleReloadInventory() {
        Task { await model.fetchLatestInventory() }
    }

    private func handlePreferredWatchTokenChange() {
        guard isLoadingSearchConfiguration == false else { return }
        Task { await loadSkus(); saveSelectedSearch() }
    }

    private func handlePreferredPhoneTokenChange() { handlePreferredWatchTokenChange() }
    private func handlePreferredMacTokenChange() { handlePreferredWatchTokenChange() }
    private func handlePreferrediPadTokenChange() { handlePreferredWatchTokenChange() }
    private func handlePreferredAirPodsTokenChange() { handlePreferredWatchTokenChange() }
    private func handlePreferredHomePodTokenChange() { handlePreferredWatchTokenChange() }
    private func handlePreferredAVPTokenChange() { handlePreferredWatchTokenChange() }

    private func handleSelectedSearchChange(_ id: UUID?) {
        guard let id else { return }
        Task { await loadSearchConfiguration(id: id) }
    }

    private func loadSearchConfiguration(id: UUID) async {
        guard let search = model.searchConfigurations.first(where: { $0.id == id }) else { return }
        searchLoadGeneration += 1
        let generation = searchLoadGeneration
        defer {
            if searchLoadGeneration == generation {
                isLoadingSearchConfiguration = false
            }
        }
        isLoadingSearchConfiguration = true
        preferredCountry = search.countryCode
        preferredStoreNumber = search.storeNumber
        selectedStore = search.storeNumber
        preferredProductType = search.family.rawValue
        selectedCountryIndex = OrderedCountries.firstIndex(of: search.countryCode) ?? 0
        await loadAllTokens()
        guard selectedSearchID == id else { return }
        setDraftToken(search.token, for: search.family)
        await loadSkus()
        guard selectedSearchID == id else { return }
        await loadStores(
            for: search.countryCode,
            filterText: nil,
            searchID: id,
            generation: generation
        )
        guard selectedSearchID == id else { return }
        await Task.yield()
    }

    private func saveSelectedSearch() {
        guard isLoadingSearchConfiguration == false,
              let currentSearchConfiguration,
              let selectedSearchID else { return }
        model.updateSearchConfiguration(
            SearchConfiguration(
                id: selectedSearchID,
                family: currentSearchConfiguration.family,
                token: currentSearchConfiguration.token,
                countryCode: preferredCountry,
                storeNumber: preferredStoreNumber
            )
        )
    }

    private func setDraftToken(_ token: String, for family: ProductFamily) {
        switch family {
        case .watch: preferredWatchToken = token
        case .iphone: preferredPhoneToken = token
        case .mac: preferredMacToken = token
        case .ipad: preferrediPadToken = token
        case .airpods: preferredAirPodsToken = token
        case .homepod: preferredHomePodToken = token
        case .avp: preferredAVPToken = token
        }
    }

    private func loadAllTokens() async {
        await loadWatchTokens()
        await loadPhoneTokens()
        await loadMacTokens()
        await loadiPadTokens()
        await loadAirPodsTokens()
        await loadHomePodTokens()
        await loadAVPTokens()
    }
}

//struct SettingsView_Previews: PreviewProvider {
//    static var previews: some View {
//        SettingsView()
//            .environmentObject(Model.testData)
//    }
//}
