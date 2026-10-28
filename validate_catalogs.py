#!/usr/bin/env python3
"""Validate generated catalogs against Git (HEAD) for region/SKU loss, and their text for scrape junk.

Catches the failure mode where Apple rate-limiting (HTTP 541 / timeouts) caused
regions to be silently dropped from a catalog file, and SKU text the scraper should
have cleaned: page markup ("<div class="), a capacity with a stray "n" ("128GBn"),
or another page's title in a familyName ("HomePod - Midnight", AppleCare+ headings), or an iPad
named with the other screen size ("13-inch iPad Pro 11-inch (M5)"), a capacity that is more than a
size ("256GB opslag"), two parts in one region with the same name, or an iPad's Wi-Fi/Cellular
disagreeing with the US name for the same base code.
Run after a scrape:

    python3 validate_catalogs.py            # all catalogs
    python3 validate_catalogs.py iPhone-16  # subset by filename fragment

Exit code 1 if any catalog lost regions vs HEAD, carries regions_failed meta, or has scrape junk.
"""
import json
import subprocess
import sys
import glob
import re

CATALOG_DIR = "InventoryWatch/Catalogs"


def head_version(path: str):
    try:
        raw = subprocess.check_output(["git", "show", f"HEAD:{path}"], stderr=subprocess.DEVNULL)
        return json.loads(raw)
    except subprocess.CalledProcessError:
        return None  # new file, nothing to compare against


MARKUP = re.compile(r'<[a-zA-Z/]|class=')
STRAY_N = re.compile(r'\d\s?(?:GB|TB|Go|To|Gt|Tt)n(?![A-Za-z])')
# What clean_capacity leaves: "256GB", "1TB", or French/Finnish "256 Go", "1 Tt".
CAPACITY = re.compile(r'\d+(?:[.,]\d+)?(?:GB|TB| Go| To| Gt| Tt)')
# A free-standing two-digit number: "11" in "11-inch" or "11 tum", not "A16", "M10" or "128GB".
TWO_DIGITS = re.compile(r'(?<![\dA-Za-z.])(\d{2})(?![\dA-Za-z.])')


def text_problems(catalog: dict) -> list:
    """SKU text the scraper should have cleaned, as "region part: issue" strings."""
    found = []
    for region, by_token in (catalog.get("discovered_models") or {}).items():
        for model in (by_token or {}).values():
            for part, sku in ((model or {}).get("skus") or {}).items():
                if not isinstance(sku, dict):
                    continue
                for field in ("name", "familyName", "capacity", "colorDisplay"):
                    value = sku.get(field) or ""
                    if MARKUP.search(value):
                        found.append(f"{region} {part}: markup in {field} {value!r}")
                    if STRAY_N.search(value):
                        found.append(f"{region} {part}: stray 'n' after a size in {field} {value!r}")
                size = re.match(r"^(\d+)inch$", sku.get("dimensionScreensize") or "")
                if size and str(sku.get("family") or "").startswith("ipad"):
                    # "13-inch iPad Pro 11-inch (M5)": a two-digit number other than the SKU's own size.
                    others = {n for n in TWO_DIGITS.findall(sku.get("name") or "") if n != size.group(1)}
                    if others:
                        found.append(f"{region} {part}: {size.group(1)}-inch SKU named with size {', '.join(sorted(others))}: {sku.get('name')!r}")
                cap = sku.get("capacity") or ""
                if cap and not CAPACITY.fullmatch(cap):
                    found.append(f"{region} {part}: capacity is not just a size: {cap!r}")
                family = sku.get("familyName") or ""
                if " - " in family or "applecare" in (family + " " + (sku.get("name") or "")).lower():
                    found.append(f"{region} {part}: another page's title in familyName/name {family!r}")
    found += _duplicate_names(catalog) + _connectivity_vs_us(catalog)
    return found


def _duplicate_names(catalog: dict) -> list:
    """Two parts in one region and model with the same name: an alert can't tell them apart."""
    found = []
    for region, by_token in (catalog.get("discovered_models") or {}).items():
        for model in (by_token or {}).values():
            seen = {}
            for part, sku in ((model or {}).get("skus") or {}).items():
                name = (sku.get("name") or "").strip() if isinstance(sku, dict) else ""
                if name:
                    seen.setdefault(name, []).append(part)
            for name, parts in seen.items():
                if len(parts) > 1:
                    found.append(f"{region} {', '.join(sorted(parts))}: same name {name!r}")
    return found


def _connectivity_vs_us(catalog: dict) -> list:
    """An iPad named Cellular where the US name of the same base code says Wi-Fi, or the reverse."""
    def cellular(name: str):
        return "Cellular" in name if ("Cellular" in name or "Wi-Fi" in name) else None
    models = catalog.get("discovered_models") or {}
    us = {}
    for model in (models.get("us") or {}).values():
        for part, sku in ((model or {}).get("skus") or {}).items():
            if isinstance(sku, dict) and str(sku.get("family") or "").startswith("ipad"):
                us[part[:5]] = cellular(sku.get("name") or "")
    found = []
    for region, by_token in models.items():
        for model in (by_token or {}).values():
            for part, sku in ((model or {}).get("skus") or {}).items():
                want = us.get(part[:5])
                got = cellular(sku.get("name") or "") if isinstance(sku, dict) else None
                if want is not None and got is not None and got != want:
                    found.append(f"{region} {part}: named {'Cellular' if got else 'Wi-Fi'}, US says {'Cellular' if want else 'Wi-Fi'}")
    return found


def main() -> int:
    fragments = [f.lower() for f in sys.argv[1:]]
    problems = []
    checked = 0
    for path in sorted(glob.glob(f"{CATALOG_DIR}/*-intl.json")):
        name = path.split("/")[-1]
        if fragments and not any(fr in name.lower() for fr in fragments):
            continue
        checked += 1
        try:
            new = json.load(open(path))
        except Exception as e:
            problems.append(f"{name}: unreadable ({e})")
            continue
        old = head_version(path)

        new_regions = set(new.get("discovered_models", {}))
        meta = new.get("_meta", {})
        failed = meta.get("regions_failed") or []

        if old is not None:
            old_regions = set(old.get("discovered_models", {}))
            lost = sorted(old_regions - new_regions)
            if lost:
                problems.append(f"{name}: LOST regions vs HEAD: {', '.join(lost)}")
        if failed:
            problems.append(f"{name}: meta reports failed regions (carried forward): {', '.join(failed)}")
        junk = text_problems(new)
        if junk:
            shown = "; ".join(junk[:3]) + (f"; and {len(junk) - 3} more" if len(junk) > 3 else "")
            problems.append(f"{name}: {len(junk)} SKU text problem(s): {shown}")

    if checked == 0:
        print("no catalogs matched")
        return 1
    if problems:
        print("FAIL: catalog validation found problems:")
        for p in problems:
            print(f"  - {p}")
        return 1
    print(f"OK: {checked} catalog(s) complete (no region loss, no failed-region meta, no scrape junk).")
    return 0


if __name__ == "__main__":
    sys.exit(main())