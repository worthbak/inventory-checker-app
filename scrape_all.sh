#!/bin/bash
# Full scrape of every product family.
#
# Families run *sequentially* (not in parallel): launching all 7 families at once
# bursts ~230 requests at Apple and reliably triggers Akamai 541 bot-blocking,
# which silently drops whole regions from the generated catalogs.
set -uo pipefail

FAMILIES=(iphone watch mac ipad airpods homepod avp)
FAILED=0

mkdir -p logs

for family in "${FAMILIES[@]}"; do
    echo "[$(date +%H:%M:%S)] Starting ${family}..."
    python3 scrape_models.py --family "$family" --all-models > "logs/scrape_${family}.log" 2>&1
    rc=$?
    if [ "$rc" -ne 0 ]; then
        echo "[$(date +%H:%M:%S)] ${family} FAILED (exit $rc) - see logs/scrape_${family}.log"
        FAILED=1
    else
        echo "[$(date +%H:%M:%S)] ${family} complete."
    fi
    sleep 5
done

if [ "$FAILED" -ne 0 ]; then
    echo "[$(date +%H:%M:%S)] One or more families failed (region fetch errors)."
    exit 1
fi
echo "[$(date +%H:%M:%S)] All families complete."