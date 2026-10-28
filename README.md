# InventoryWatch

macOS app to monitor Apple Store pickup availability for iPhone, Apple Watch, Mac, iPad, AirPods, HomePod, and Apple Vision Pro.

> **Originally created by [Worth Baker](https://github.com/worthbak) (@worthbak).**
> The project was handed over to [@drallgood](https://github.com/drallgood) for continued
> maintenance, and this repository was transferred with its full history, issues, and
> contributors intact. Thank you, Worth, for building InventoryWatch and letting it keep growing.

## Features

- Real-time inventory checking across Apple Store locations
- Multiple saved searches, each with its own country and store
- Master-detail search settings with immediate saving, plus separate inventory results for each search
- Per-country store selection (35+ countries, including multi-language stores in Belgium and Switzerland)
- Per-model token selection for all Apple product families (iPhone, iPad, Mac, Apple Watch, AirPods, HomePod, Apple Vision Pro)
- Configurable update intervals with notifications
- Automatic app update checks and signed update installation through Sparkle
- Stable and beta update channels
- All product data is scraped from Apple's official buy pages — no hardcoded SKUs

See the [changelog](CHANGELOG.md) for change history and [historical refactoring notes](REFACTORING_NOTES.md) for the earlier architecture and scraper work.

## Managing searches

Open Settings using the gear button. The sidebar lists saved searches; select one
to edit its product family, model, country, and store in the detail pane. Changes
save immediately. **New Search** creates another search from the current product
and location selections; edit the new entry to monitor a different product or
location. Use the trash button or **Delete Search** context-menu action to remove
the selected search.

Each search has its own country and store, so you can monitor different products
and countries at the same time. Changing country loads that country's model
choices and selects its first available store; choose another store as needed.
If the selected family has no usable catalog data there, the app restores the
previous search instead of saving an unsupported setup.

The inventory window groups results by search. Store labels show a recognizable
name and city, for example **Near Apple Memorial City — Houston, TX**. **Near**
means the shared **Include results from nearby stores** setting is enabled;
**At** means only the selected store is requested. A search without a store shows
**No store selected**; an unresolved store name temporarily falls back to its ID.

Product, country, and store are per-search settings. Refresh interval,
preferred-model filtering, notification filtering, nearby-store inclusion, custom
SKU, and text size remain app-wide settings. Preferred-model selections are kept
when switching products. Notifications deduplicate availability shared by
overlapping searches.

Existing single-search preferences and older saved searches migrate
automatically, retaining their previous country and store. On first launch
after the bundle identifier change, preferences from the previous app
identifier are imported without overwriting values already saved by the new
identifier. Searches with the same country and store share a pickup request;
other locations are queried separately.

## Architecture

- **SwiftUI** macOS app with MVVM + Actor model
- **Sparkle** for signed app updates from the GitHub Pages appcast
- Product/SKU data loaded from JSON catalog files (`InventoryWatch/Catalogs/`)
- Python scraper (`scrape_models.py`) generates catalog JSONs from Apple's regional buy pages
- Store data from Apple's `rsp-web/store-list` API with local JSON fallback
- Saved searches persist with stable identities; inventory results are scoped to each search
- All configuration driven by JSON: product families, countries, SKU data, store locations

## Project Structure

```
InventoryWatch/
├── Model/
│   ├── SKUDataLoader.swift          # Actor that loads SKU data from catalog JSONs
│   ├── FulfillmentModel.swift       # Apple pickup API queries
│   ├── DefaultsVendor.swift         # User preferences (ProductFamily enum)
│   ├── ViewModel.swift              # SwiftUI ViewModel (MainActor)
│   ├── NotificationManager.swift    # macOS notifications
│   ├── NotificationSender.swift     # Notification logic
│   ├── CatalogTypes.swift           # Shared types (CategoryCatalog protocol)
│   ├── JSONCatalog*.swift           # Per-family catalog enums
│   └── ModelTypes/                  # Data structures
├── Views/
│   └── ProductAvailabilityList.swift # Reusable product list component
├── SettingsView.swift               # Preferences window
├── ContentView.swift                # Main inventory display
├── Countries.swift                  # Country data (loaded from countries.json)
├── Catalogs/
│   ├── countries.json               # 35 countries with shortcodes, locales, multi-language variants
│   ├── Stores_GlobalBootstrap.json   # Store locations (536 stores, 26 countries)
│   └── *-intl.json                  # Per-model catalog files (35+ files covering all 7 product families)
├── Assets.xcassets/                 # App icon
└── InventoryWatchTests/             # Unit tests (catalog parsing, country data, SKU resolution)
```

## Setup

### Build the app

```bash
open InventoryWatch.xcodeproj
# Build (Cmd+B) then Run (Cmd+R) in Xcode
```

Use a current Xcode installation and a macOS version supported by its SDK. The
app target uses Xcode's recommended macOS deployment target; the test target
currently requires macOS 27.0.

### App updates

InventoryWatch checks the update feed daily and offers new releases for installation. Choose **InventoryWatch > Check for Updates…** to check manually. Choose **InventoryWatch > Update Channel** to switch between **Stable** and **Beta**.

Stable updates are published without a `sparkle:channel` element; beta updates include `<sparkle:channel>beta</sparkle:channel>`. Beta users receive beta updates and stable releases. Stable users only receive stable releases.

Generate a Sparkle EdDSA key pair with Sparkle's `generate_keys` tool and keep the private key in the login Keychain used for releases (never commit it). Configure the app's `SPARKLE_PUBLIC_ED_KEY` Xcode build setting with the matching public key. The updater remains disabled until a valid public key is configured.

Sparkle replaces the previous GitHub-tag version check. The checked-in appcast
starts with no release items; the release script publishes the first signed
release and updates the feed automatically.

### Sign and notarize a release

For direct distribution outside the Mac App Store, use [`scripts/release.sh`](scripts/release.sh). It requires full Xcode, an active Apple Developer Program membership, and a **Developer ID Application** certificate with its private key installed in your login Keychain. An Apple Development certificate is not sufficient.

1. Store notarization credentials in Keychain once with an app-specific password and your Apple Developer team ID:

   ```bash
   xcrun notarytool store-credentials inventorywatch-notary \
     --apple-id 'you@example.com' \
     --team-id 'YOUR_TEAM_ID'
   ```

   Enter the app-specific password at the secure terminal prompt. Do not put passwords, private keys, or certificate exports in the repository or chat.

2. Configure the matching Sparkle public key in the Xcode `SPARKLE_PUBLIC_ED_KEY` build setting (it is safe to store the public key in the project) or export it in your shell. Keep the private key in the login Keychain. Authenticate the GitHub CLI once with `gh auth login`, enable GitHub Pages for the `main` branch's `docs/` directory, then run the release command from a clean, up-to-date `main` checkout:

   ```bash
   SPARKLE_PUBLIC_ED_KEY=YOUR_PUBLIC_KEY \
   RELEASE_CHANNEL=stable \
   bash scripts/release.sh
   ```

   The script detects the Apple team ID from the Xcode project, runs the test suite, increments and commits the build number, signs the Sparkle helper tools and app, notarizes and staples the archive, and checks Gatekeeper. It then creates a uniquely tagged GitHub release with the ZIP and checksum, updates the appcast, and pushes both commits so GitHub Pages publishes the update feed. Set `RELEASE_CHANNEL=beta` for a beta release.

Install the release-note renderer once with
`python3 -m pip install -r scripts/requirements-release.txt` (use a virtual
environment if required by your Python installation). Release packaging embeds
HTML notes in the appcast so Sparkle displays what changed in its update dialog.
The same section is included as Markdown in the GitHub release, ahead of
GitHub's automatically generated notes.
Notes come from the exact `## <marketing version>` heading in
[`CHANGELOG.md`](CHANGELOG.md), falling back to `## Unreleased` if that version
has no section. Empty or missing notes stop the release before building.
Before releasing, move the relevant Unreleased entries under the version heading
and leave Unreleased for subsequent changes. Existing releases' notes can also be
updated directly in the appcast without rebuilding the app.

To run tests and verify signing without incrementing the build number, notarizing, or publishing:

```bash
SPARKLE_PUBLIC_ED_KEY=YOUR_PUBLIC_KEY \
bash scripts/release.sh --build-only
```

The team ID is inferred from the Xcode project; `TEAM_ID` can override it. Use `SIGNING_IDENTITY` to select a specific Developer ID Application identity or `NOTARY_PROFILE` to select another saved Keychain profile. `RELEASE_REPOSITORY`, `RELEASE_REMOTE`, and `RELEASE_BRANCH` can override the publishing destination. `RELEASE_TAG` can override the generated tag. The script retains build output and diagnostic logs under the ignored `build/release/` directory.

The release command pushes two small commits to the release branch: the new
build number and the appcast item. Ensure the GitHub Pages source is configured
to publish `main/docs`, and keep the repository and Pages domain consistent
with the app's `SUFeedURL`.

### Scrape product data

```bash
# Install Python dependencies
pip install requests

# Scrape all iPhone models across all regions
python3 scrape_models.py --family iphone --all-models

# Scrape a specific family
python3 scrape_models.py --family ipad --all-models

# Targeted scrape for specific countries
python3 scrape_models.py --family mac --all-models --countries US,UK,DE
```

Available families: `iphone`, `watch`, `mac`, `ipad`, `airpods`, `homepod`, `avp`

Or use the convenience script to scrape all families at once:
```bash
bash scrape_all.sh
```

Configuration is in `scraper_config.json` (regions, categories, model variants, families). See [Scraper Config Reference](#scraper-config-reference) below.

After scraping, check the catalogs before committing:
```bash
python3 validate_catalogs.py
```
It fails on region loss against the committed catalog, failed-region metadata, and scrape junk
in names or capacities (leftover HTML markup, a stray `n` after a size such as `256 GBn`, or a
product title leaked into another product's name).

### Scrape store data

```bash
python3 scrape_apple_stores.py
```

Outputs `Stores_GlobalBootstrap.json` to `InventoryWatch/Catalogs/`

## Configuration

All configuration is JSON-driven:

| Config | File | Purpose |
|---------|------|---------|
| Countries | `InventoryWatch/Catalogs/countries.json` | Country names, shortcodes, locales, SKU codes, multi-language variants (BE, CH) |
| Stores | `InventoryWatch/Catalogs/Stores_GlobalBootstrap.json` | Store locations (536 stores, 26 countries) |
| Products | `InventoryWatch/Catalogs/*-intl.json` | SKUs, names, colors, capacities per country |
| Scraper | `scraper_config.json` | Regions, categories, entrypoints, families with per-product-type behavior flags, and model variant patterns (Pro/Max/Air/etc.) used to derive display names from product codes |

## Testing

```bash
# Run tests from Xcode (Cmd+U)
# Or from command line:
xcodebuild test -project InventoryWatch.xcodeproj -scheme InventoryWatch
```

Tests cover catalog JSON parsing, country data loading, product family resolution,
SKU lookup, saved-search round trips and migration, pickup request/response
handling, request cooldowns, and human-readable store labels.

## Credits

- **Worth Baker ([@worthbak](https://github.com/worthbak))** — original author of InventoryWatch.
  Worth started the project in November 2021 and authored 167 commits in this
  repository, maintaining it through v0.3.1. The project was handed over for continued
  maintenance in 2026; the repository and its open issues were transferred intact from
  `worthbak/inventory-checker-app`, so the history here is his work as much as the current
  maintainer's. Thank you, Worth — for building this and for letting it keep going.
- **[@drallgood](https://github.com/drallgood)** — current maintainer, responsible for the
  v3.0 rewrite, multi-search support, and the signed, notarized release pipeline.
- **Brad Bergeron, Pedro Teixeira, and Andre Briggs** — additional contributors whose work is
  part of this repository's history.

Thanks to everyone who filed an issue, sent a pull request, or reported a bug — this app is
better because of you.

## Intentional Hardcodes

A few values are intentionally hardcoded because they represent Apple's API contract or operational defaults:

- Apple pickup API query params (`fae=true`, `little=false`, etc.) — API protocol, not configuration
- HTTP timeout (30s) and a reused ephemeral URLSession for connection reuse
- User-Agent and Accept headers — request metadata, not a guarantee of acceptance by bot protection
- Notification cleanup window (7 days) — reasonable default
- Update interval default (5 minutes) — avoids excessive API calls

### Blocked inventory requests

An HTTP 541 response pauses all pickup searches for 60 seconds instead of triggering
immediate retries. The pause does not escalate and is kept only in memory for the
current app session. It applies to manual refresh and configuration changes.
This is a conservative application default, not an Apple-published limit.

The app honors `Retry-After` (seconds or an HTTP date) on 541, 429, and 503 responses,
using longer server delays in preference to the 60-second pause. A 429 without a
valid delay pauses checks for one minute. The error message shows when requests
are permitted again; automatic checks resume on the next scheduled refresh after
that time. Existing results are retained on refresh errors and may be stale.
Overlapping refresh triggers are coalesced, and configuration changes made during
a request are checked after it completes rather than starting parallel requests.
URLSession cannot execute browser JavaScript challenges, and these measures do not
guarantee access to Apple's endpoint.

## Scraper Config Reference

`scraper_config.json` drives the Python scraper (`scrape_models.py`). It has five top-level sections:

### `http_headers`

HTTP headers sent by the Python scraper. Browser-like headers alone do not guarantee
acceptance by Apple's bot protection.

### `regions`

Array of country/region entries. Each entry defines an Apple Store regional domain.

| Field        | Description |
|--------------|-------------|
| `url_prefix` | Base URL of the regional Apple Store (e.g. `https://www.apple.com/de/`) |
| `suffix`     | Apple part number suffix for that region (e.g. `ZD/A` for Germany) |
| `name`       | Human-readable region name |
| `code`       | Short region code (matches URL path, e.g. `de`, `us`, `cn`) |

**To add a new region:** copy an existing entry, change `url_prefix` to the new country's Apple Store URL, set the correct part number suffix (look at a product page on that store and check the model number, e.g. `MXXXXLL/A`), and give it a unique `code`.

### `categories`

Maps product families to Apple.com entrypoint URLs. Each entry defines:

| Field           | Description |
|-----------------|-------------|
| `family`        | Internal family key (must match a key in `families`) |
| `entrypoints`   | URL paths to scrape under the regional domain (e.g. `shop/buy-iphone`) |
| `manual_tokens` | (Optional) Override token discovery. If set, only these URL path segments are scraped instead of auto-discovered tokens. Used for products like AirPods and HomePod where the buy page structure doesn't map cleanly to individual models. |

**To add a new product category:** add an entry with the family key, the Apple buy-page path(s) in `entrypoints`, and `manual_tokens` if the buy page has sub-pages for each model variant.

### `model_variants`

Maps product family keys to variant suffix patterns used to derive human-readable display names from product codes (e.g. `iphone17pro` → "iPhone 17 Pro"). Each variant pattern has:

| Field        | Description |
|--------------|-------------|
| `family_key` | Substring to match in the product family code (e.g. `promax`, `se`) |
| `suffix`     | Display label to append (e.g. `Pro Max`, `SE`) |
| `priority`   | Lower number = higher priority. Patterns are tried in priority order and the first match wins. |

**To add a new variant** (e.g. if Apple introduces an "iPhone Slim"): add a new entry under the relevant family with a unique `family_key` (a token to match in the product code) and `suffix` (the display label). Set `priority` to control which variant is preferred when multiple match.

If the product family code does not match any `family_key`, the fallback also checks the page title text for the `suffix` string. If neither matches, the base model name is returned without a suffix.

Families like `airpods`, `homepod`, and `avp` have no variant entries because their model names are self-describing (e.g. "AirPods Pro 3").

### `families`

Per-family behavioral flags that control scraping, extraction, and output. Each family entry has:

| Field                       | Description |
|-----------------------------|-------------|
| `display_name`              | Human-readable label used in logs and output filenames |
| `file_prefix`               | Prefix for the output JSON catalog file (e.g. `iPhone-intl.json`) |
| `part_number_prefix`        | (Optional) Single-letter prefix for part number extraction (e.g. `M` for Mac). Only needed when the page references part numbers like `MXXXXLL/A`. Set to `null` if not applicable. |
| `retry_full_price`          | If `true`, re-request the buy page with `purchaseOption=fullPrice` to surface higher-tier configs (e.g. Apple Watch Edition models) |
| `skip_screensize_extraction` | If `true`, skip extracting screen sizes from the page. Use for Mac where sizes aren't relevant. |
| `prune_keep_incomplete`     | If `true`, keep products with missing price data instead of dropping them. Use for families where part numbers alone are sufficient. |
| `prune_keep_regional_name`  | If `true`, keep region-specific variant names instead of normalizing to a single canonical name. Use for Mac where config names differ by region. |
| `post_filter_keep_minimal`  | If `true`, keep only the minimal set of required fields (`partNumber`, `modelDisplayName`, `sizes`). Reduces output size for families with large buy pages. |
| `bto_extraction`            | If `true`, extract build-to-order (BTO) part numbers from the page's metrics JSON. Only Mac needs this. |
| `handler`                   | (Optional) Python class name for family-specific extraction logic (e.g. `IPhoneHandler`, `MacHandler`). Set to `null` to use the generic handler. |

**To add a new product family:** add a new key to `families` with the behavioral flags above, add a matching `categories` entry with entrypoints, and (optionally) add `model_variants` if the family has variant suffixes. If the product needs custom extraction logic, create a handler class in `family_handlers.py` and reference it here.