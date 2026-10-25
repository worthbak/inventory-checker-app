import Foundation
import Testing
@testable import InventoryWatch

struct LegacyPreferencesMigrationTests {

    @Test func migrationPreservesCurrentPreferencesAndRunsOnlyOnce() throws {
        let suiteName = "InventoryWatchTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        let oldDomain = "\(suiteName).old"
        let newDomain = "\(suiteName).new"
        defer {
            defaults.removePersistentDomain(forName: oldDomain)
            defaults.removePersistentDomain(forName: newDomain)
        }

        let savedSearches = Data(#"[{"family":"iphone","token":"iphone-17"}]"#.utf8)
        defaults.setPersistentDomain(
            [
                "preferredCountry": "GB",
                "searchConfigurations": savedSearches,
                "preferredSKUs": "old-favorite"
            ],
            forName: oldDomain
        )
        defaults.setPersistentDomain(
            [
                "preferredCountry": "CA",
                "customPreference": "keep"
            ],
            forName: newDomain
        )

        #expect(LegacyPreferencesMigration.migrate(using: defaults, from: oldDomain, to: newDomain))

        let migrated = try #require(defaults.persistentDomain(forName: newDomain))
        #expect(migrated["preferredCountry"] as? String == "CA")
        #expect(migrated["customPreference"] as? String == "keep")
        #expect(migrated["searchConfigurations"] as? Data == savedSearches)
        #expect(migrated["preferredSKUs"] as? String == "old-favorite")

        defaults.setPersistentDomain(["preferredCountry": "DE"], forName: oldDomain)
        #expect(LegacyPreferencesMigration.migrate(using: defaults, from: oldDomain, to: newDomain) == false)
        #expect(defaults.persistentDomain(forName: newDomain)?["preferredCountry"] as? String == "CA")
    }
}
