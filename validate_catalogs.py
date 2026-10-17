#!/usr/bin/env python3
"""Validate generated catalogs against Git (HEAD) for region/SKU loss.

Catches the failure mode where Apple rate-limiting (HTTP 541 / timeouts) caused
regions to be silently dropped from a catalog file. Run after a scrape:

    python3 validate_catalogs.py            # all catalogs
    python3 validate_catalogs.py iPhone-16  # subset by filename fragment

Exit code 1 if any catalog lost regions vs HEAD, or carries regions_failed meta.
"""
import json
import subprocess
import sys
import glob

CATALOG_DIR = "InventoryWatch/Catalogs"


def head_version(path: str):
    try:
        raw = subprocess.check_output(["git", "show", f"HEAD:{path}"], stderr=subprocess.DEVNULL)
        return json.loads(raw)
    except subprocess.CalledProcessError:
        return None  # new file, nothing to compare against


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

    if checked == 0:
        print("no catalogs matched")
        return 1
    if problems:
        print("FAIL: catalog validation found problems:")
        for p in problems:
            print(f"  - {p}")
        return 1
    print(f"OK: {checked} catalog(s) complete (no region loss, no failed-region meta).")
    return 0


if __name__ == "__main__":
    sys.exit(main())