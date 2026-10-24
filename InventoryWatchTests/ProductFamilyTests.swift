import Testing
import Foundation
@testable import InventoryWatch

struct ProductFamilyTests {

    @Test func allCasesContainsWatchPhoneMacIPad() {
        let cases = ProductFamily.allCases
        #expect(cases.contains(.watch), "allCases should contain watch")
        #expect(cases.contains(.iphone), "allCases should contain iphone")
        #expect(cases.contains(.mac), "allCases should contain mac")
        #expect(cases.contains(.ipad), "allCases should contain ipad")
        #expect(cases.contains(.airpods), "allCases should contain airpods")
        #expect(cases.contains(.homepod), "allCases should contain homepod")
        #expect(cases.contains(.avp), "allCases should contain avp")
    }

    @Test func displayNameReturnsExpectedValues() {
        #expect(ProductFamily.watch.displayName == "Apple Watch")
        #expect(ProductFamily.iphone.displayName == "iPhone")
        #expect(ProductFamily.mac.displayName == "Mac")
        #expect(ProductFamily.ipad.displayName == "iPad")
        #expect(ProductFamily.airpods.displayName == "AirPods")
        #expect(ProductFamily.homepod.displayName == "HomePod")
        #expect(ProductFamily.avp.displayName == "Apple Vision Pro")
    }

    @Test func isPropertiesAreMutuallyExclusive() {
        let all: [ProductFamily] = [.watch, .iphone, .mac, .ipad, .airpods, .homepod, .avp]
        for family in all {
            var count = 0
            if family.isWatch { count += 1 }
            if family.isIPhone { count += 1 }
            if family.isMac { count += 1 }
            if family.isIPad { count += 1 }
            if family.isAirPods { count += 1 }
            if family.isHomePod { count += 1 }
            if family.isAVP { count += 1 }
            #expect(count == 1, "\(family) should have exactly one isX property true")
        }
    }

    @Test func searchConfigurationsSupportMultipleFamiliesAndRoundTrip() throws {
        let searches = [
            SearchConfiguration(family: .iphone, token: "iphone-17", countryCode: "US", storeNumber: "R001"),
            SearchConfiguration(family: .watch, token: "apple-watch", countryCode: "CA", storeNumber: "R002")
        ]
        let encoded = try JSONEncoder().encode(searches)
        let decoded = try JSONDecoder().decode([SearchConfiguration].self, from: encoded)

        #expect(decoded == searches)
        #expect(Set(decoded.map(\.id)).count == 2)
        #expect(decoded.map(\.countryCode) == ["US", "CA"])
        #expect(decoded.map(\.storeNumber) == ["R001", "R002"])
    }

    @Test func searchConfigurationIdentityIncludesFamilyAndToken() {
        let phone = SearchConfiguration(family: .iphone, token: "iphone-17")
        let anotherPhone = SearchConfiguration(family: .iphone, token: "iphone-17-pro")
        let watch = SearchConfiguration(family: .watch, token: "iphone-17")

        #expect(phone != anotherPhone)
        #expect(phone != watch)
    }

    @Test func searchConfigurationDecodesPreviousFormat() throws {
        let data = Data(#"{"family":"iphone","token":"iphone-17"}"#.utf8)
        let decoded = try JSONDecoder().decode(SearchConfiguration.self, from: data)

        #expect(decoded.family == .iphone)
        #expect(decoded.token == "iphone-17")
        #expect(decoded.countryCode == (UserDefaults.standard.string(forKey: "preferredCountry") ?? "US"))
        #expect(decoded.storeNumber == UserDefaults.standard.preferredStoreNumber)
    }
}