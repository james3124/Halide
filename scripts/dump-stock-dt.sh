#!/bin/bash
# dump-stock-dt.sh — capture the stock DT for overlay authoring (ch.11 porting week plan, step 2).
# Real run needs the stock device dumped over fastboot/EDL: lab/device only, never on builder.
# Phone-safe: guards out with exit 2; documents the capture recipe per ch.03 §13 provenance rule.
set -eu
command -v fastboot >/dev/null 2>&1 || {
  echo "REFUSED: fastboot not present — stock-DT dump is a lab/device step, not phone/builder."
  echo "Real logic (ch.11 new-SKU onboarding step 2 + ch.03 S13):"
  echo "  1. fastboot boot stock recovery OR EDL firehose pull of the stock dtbo partition"
  echo "  2. mkdtboimg dump dtbo.img -> per-board dtbo entries"
  echo "  3. fdtdump each entry > dumps/stock-dt-<sku>-<date>/ (keep original bytes too)"
  echo "  4. provenance comments in new overlays cite these dumps (dtbo-lint.py enforces)"
  exit 2
}
SKU=${1:?usage: dump-stock-dt.sh <sku> [out-dir]}
OUT=${2:-dumps/stock-dt-$SKU-$(date -u +%Y%m%d)}
echo "device tooling present but full stock-DT capture needs the stock unit attached (lab only)"
echo "would write: $OUT (recipe in comments above, per ch.03 S13)"
exit 2
