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

- Refreshed every product catalog, including iPad mini (A20 Pro), the M6 MacBook Pro configurations and the M6 iMac.
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
  - Preconfigured Macs take their screen size and display finish from their own product entry where the page provides one, and the fallback search around the part number no longer reads the previous product. It had labelled 16-inch MacBook Pros as 14-inch and added nano-texture to configurations without it. Where a page gives only core counts, names include the plain chip from the container code ("M6" on iMac, "M5" on MacBook Air).
  - Capacities and names no longer keep cut-off page markup such as `128GBn<div class=` or `128 GBn` (iPad pages).
  - China names no longer start with another page's US title ("HomePod - Midnight 午夜色", "iPad Wi‑Fi 128GB - Blue …", or an AppleCare+ heading as an Apple Watch family name). They use the region's own family name for that screen size or, when every name in the region is affected, the one most countries use. Names that can't be repaired are reported.
  - AppleCare+ plans a buy page offers (`planDetails`, such as Brazil's Mac plans `MN863BR/A`) are no longer listed as products for regions fetched in the run.
  - A catalog whose generated file name differs only in case from an existing one (`Mac-iMac` and `Mac-Imac`) reuses the existing file, so case-sensitive file systems don't get a second copy next to the bundled one.
  - 13-inch iPad Pro and iPad Air names no longer carry the 11-inch model's title ("13-inch iPad Pro 11-inch (M5)"). iPad names use each configuration's own family name, with the chip from the page title.
  - The product-selection data is parsed even when product copy contains ", word:" (Sweden's ", reparerbarhet:" had broken it), so Swedish iPads get their glass type and screen size again.
  - iPad Wi-Fi/Cellular comes from each product's own entry. A scan forward from `dimensionConnection` had read the next product's part number and named 8 Swedish iPads with the wrong connectivity.
  - Capacities are just the size in every language: "256GB" instead of "256GB opslag", "พื้นที่จัดเก็บข้อมูล 256GB" or "256GBストレージ", and "256 Go" instead of "256 Go de" or "256 Gon". Macs read French "Go" and Finnish "Gt", so MacBook Neo has a capacity there.
  - The product name search skips EU energy labels, whose titles are a PDF's ("Produktinformationsblad PDF, iPad"); iPad names now include the chip in every country.
  - Soft hyphens and direction marks are removed from names and colors.
  - `validate_catalogs.py` also fails on scrape junk in SKU text: page markup, a capacity that is more than a size, a stray "n" after a size, another page's or a PDF's title in a name, an iPad named with the other screen size, two parts in one region with the same name, and an iPad's Wi-Fi/Cellular disagreeing with the US name for the same configuration.

### Release notes

- These changes are not yet a published release. The appcast contains no release items until a signed release ZIP and its generated item are published.
- Release packaging does not upload GitHub releases or deploy GitHub Pages automatically. See the [release instructions](README.md#sign-and-notarize-a-release).
- Earlier architecture and scraper work is documented in [REFACTORING_NOTES.md](REFACTORING_NOTES.md).
