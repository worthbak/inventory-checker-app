---
image:
  path: https://drallgood.github.io/inventory-checker-app/logo.png
  width: 512
  height: 512
  alt: InventoryWatch app icon
twitter:
  card: summary
---

# InventoryWatch

A macOS app to monitor Apple Store pickup availability for iPhone, Apple Watch, Mac, iPad, AirPods, HomePod, and Apple Vision Pro.

This is the open-source macOS version of InventoryWatch, including multiple saved searches. For the commercial service with web access and email/SMS notifications, visit [InventoryWatch.app](https://inventorywatch.app).

## Features

- Real-time inventory checking across Apple Store locations in 35+ countries
- Support for all Apple product families: iPhone, iPad, Mac, Apple Watch, AirPods, HomePod, Apple Vision Pro
- Per-model and per-country token selection with persistent preferences
- Multiple saved searches with independent country/store selections and a master-detail Settings editor
- Separate results for each search, with readable store names and locations
- Configurable update intervals with macOS notifications
- Signed app updates through Sparkle, with stable and beta channels once a release feed is configured and published
- All product data scraped from Apple's official buy pages — no hardcoded SKUs

## Quick Start

```bash
# Clone and build
git clone https://github.com/drallgood/inventory-checker-app.git
cd inventory-checker-app
open InventoryWatch.xcodeproj  # Build (Cmd+B) then Run (Cmd+R)
```

Use a current Xcode installation and a macOS version supported by its SDK. The app uses Xcode's recommended deployment target; the test target currently requires macOS 27.0.

### Regenerate Product Data

```bash
pip install requests
python3 scrape_models.py --family iphone --all-models
python3 scrape_apple_stores.py
```

See [README.md](../README.md) for full documentation, architecture, and scraper configuration reference.

## Project Status

### Search management and reliability

- Existing searches migrate automatically to the new independent search format.
- Searches sharing a country/store use a combined pickup request; different locations are queried separately.
- Country changes validate catalog availability before saving, and preferred-model selections survive product changes.
- Refresh triggers are coalesced, duplicate availability is removed from notifications, and blocked requests use a session-wide cooldown that honors supported `Retry-After` headers.
- Release tooling tests, builds, signs, notarizes, publishes GitHub releases, and updates the signed Sparkle appcast on GitHub Pages.

See the [changelog](../CHANGELOG.md) for change history and the [README](../README.md) for search, update-channel, and release instructions.

### Earlier refactoring

Actively maintained as of 2025 with major refactoring completed:

- **Config-driven Python scraper**: `scrape_models.py` + `family_handlers.py` + `scraper_config.json` generates all catalog JSONs from Apple.com
- **Data-driven architecture**: All SKUs, countries, and stores externalized to JSON — no hardcoded product data in Swift
- **Full product family support**: iPhone (16, 17, 17e, 17 Pro, Air), iPad (Pro, Air, Mini, base), Mac (Air, Pro, Neo, iMac, Mini, Studio, Displays), Apple Watch (SE, Ultra, Hermes), AirPods (4, Max, Pro 2, Pro 3), HomePod, Apple Vision Pro
- **Multi-language stores**: Belgian (Dutch/French) and Swiss (German/French) dual-language store support
- **Anti-bot hardening**: Proper HTTP/1.1 handling and backoff for Apple's Akamai CDN

For historical architecture and scraper details, see [REFACTORING_NOTES.md](../REFACTORING_NOTES.md).