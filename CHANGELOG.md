# Changelog

## Unreleased

### Added

- Multiple saved product searches across all supported Apple product families, each with its own country and Apple Store.
- A master-detail Settings layout with a search sidebar, **New Search**, deletion controls, and immediate saving of edits to the selected search.
- Separate inventory result sections for each search, with country-specific product links and availability.
- Human-readable store labels, such as **Near Apple Memorial City — Houston, TX**, or **At Apple Memorial City — Houston, TX** when nearby stores are disabled.
- Sparkle app updates with daily checks, **Check for Updates…**, and persistent **Stable** and **Beta** channel selection. The updater requires a configured HTTPS feed and valid EdDSA public key.
- A GitHub Pages appcast template and release tooling for universal Apple Silicon/Intel archives, Developer ID signing, notarization, stapling, signature verification, ZIP checksums, and signed stable/beta appcast items.
- Regression tests for search persistence and migration, pickup request construction and response handling, cooldown behavior, and store-location labels.

### Changed

- Refreshed iPad, Mac, Apple Watch, HomePod and AirPods catalogs, including iPad mini (A20 Pro), the M6 MacBook Pro configurations and the M6 iMac.
- Existing single-search preferences and earlier family/model-only saved searches migrate to independently identified searches using the previous country and store settings.
- Searches sharing a country and store are combined into one pickup request. Different locations are queried separately, and results are scoped to the corresponding search.
- Preferred-model selections are retained when switching products. Favorites from unrelated searches are excluded from pickup queries, and an empty preferred-only selection does not trigger an invalid request.
- Country changes validate the available model catalog before saving. Unsupported changes restore the previous search, and stale asynchronous editor loads cannot overwrite a newer selection.
- Notifications use the configured searches rather than the global product picker. Overlapping searches do not count the same country/store/part availability twice.
- Inventory refreshes reuse an ephemeral URLSession and coalesce overlapping triggers rather than cancelling in-flight requests. Changed configurations are refreshed after the current request completes.
- Apple bot blocks pause pickup checks for one minute instead of immediately retrying. Rate-limit responses honor supported `Retry-After` values, and the UI reports when checks can resume. This cooldown applies across searches for the current app session; it does not guarantee access to Apple's endpoint.
- Sparkle replaces GitHub-tag version polling and the old update-download indicator.

### Fixed

- Search headings and sidebar labels no longer repeat the product family when it is already part of the model name.
- Pickup warnings are collected across location groups, and the configured store is prioritized within its search's results.
- Refresh errors retain existing results, which may be stale, rather than replacing them with a successful-looking empty result.
- The SKU-name regression test now uses the existing SKU lookup API, allowing the test target to compile instead of leaving an incomplete unsigned test bundle after a failed build.
- Catalog scraper accuracy (Oct 2026 catalog refresh):
  - Preconfigured Macs take their screen size and display finish from their own product entry on the buy page. A window around the part number had often reached into the previous product, labelling 16-inch MacBook Pros as 14-inch and adding nano-texture to configurations without it. iMac and MacBook Air names include the chip from the container code (for example, "M6").
  - Capacities and names no longer keep cut-off page markup such as `128GBn<div class=` (iPad pages).
  - China names no longer start with another page's US title ("HomePod - Midnight 午夜色", "iPad Wi‑Fi 128GB - Blue …", or an AppleCare+ heading as an Apple Watch family name). They use the family name the other countries share.
  - AppleCare+ plans a buy page offers (`planDetails`, such as Brazil's Mac plans `MN863BR/A`) are no longer listed as products.
  - A catalog whose generated file name differs only in case from an existing one (`Mac-iMac` and `Mac-Imac`) reuses the existing file, so case-sensitive file systems don't get a second copy next to the bundled one.

### Release notes

- These changes are not yet a published release. The appcast contains no release items until a signed release ZIP and its generated item are published.
- Release packaging does not upload GitHub releases or deploy GitHub Pages automatically. See the [release instructions](README.md#sign-and-notarize-a-release).
- Earlier architecture and scraper work is documented in [REFACTORING_NOTES.md](REFACTORING_NOTES.md).
