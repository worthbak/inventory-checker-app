import Testing
@testable import InventoryWatch

@MainActor
struct StoreLocationLabelTests {
    private let store = RetailStore(
        id: "R164",
        name: "Memorial City",
        telephone: "",
        slug: "memorialcity",
        address: StoreAddress(
            city: "Houston",
            address1: nil,
            address2: nil,
            stateName: "Texas",
            stateCode: "TX",
            postalCode: nil
        )
    )

    @Test func nearbyLabelUsesStoreNameAndLocation() {
        #expect(ContentView.storeLocationLabel(
            store: store, storeNumber: "R164", includeNearbyStores: true
        ) == "Near Apple Memorial City — Houston, TX")
    }

    @Test func exactStoreLabelUsesAt() {
        #expect(ContentView.storeLocationLabel(
            store: store, storeNumber: "R164", includeNearbyStores: false
        ) == "At Apple Memorial City — Houston, TX")
    }

    @Test func missingStoreHasExplicitFallback() {
        #expect(ContentView.storeLocationLabel(
            store: nil, storeNumber: "R164", includeNearbyStores: true
        ) == "Near selected store (R164)")
        #expect(ContentView.storeLocationLabel(
            store: nil, storeNumber: "", includeNearbyStores: true
        ) == "No store selected")
    }

    @Test func existingApplePrefixIsNotRepeated() {
        var namedStore = store
        namedStore.name = "Apple Memorial City"
        #expect(ContentView.storeLocationLabel(
            store: namedStore, storeNumber: "R164", includeNearbyStores: true
        ) == "Near Apple Memorial City — Houston, TX")
    }
}
