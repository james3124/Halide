#!/bin/bash
# dtbo-apply-check.sh — verify overlay apply without flashing (ch.03 S40 step 5).
# Real run needs a kernel build tree (base.dtb + dtbo.img + libufdt/fdtdiff): builder/device only.
# Phone-safe: guards out with exit 2; validates argument shape + documented procedure below.
set -eu
BASE=""; BUNDLE=""
while [ $# -gt 0 ]; do
  case "$1" in
    --base) BASE=${2:?}; shift 2 ;;
    --bundle) BUNDLE=${2:?}; shift 2 ;;
    --board-id|--dump-merged) shift 2 ;;
    *) shift ;;
  esac
done
[ -n "$BASE" ] || { echo "usage: dtbo-apply-check.sh --base <dtb> --bundle <dtbo.img> --board-id <sku> --dump-merged <out.dtb>"; exit 2; }

# Procedure on builder (ch.03 S40): mkdtboimg dump -- extract per board-id entry ->
# apply with libufdt apply -> fdtdiff base vs merged -> assert only regulator/panel/touch nodes;
# any chosen/bootargs or /memory delta = FAIL (overlays never touch those).
for tool in fdtdump fdtget; do
  command -v "$tool" >/dev/null 2>&1 || {
    echo "REFUSED: device-tree tools (fdtdump/fdtget) not installed — kernel-tree/builder only."
    echo "Real logic per ch.03 S40: libufdt apply on base+dtbo, fdtdiff review, board-id matrix match."
    exit 2
  }
done
[ -f "$BASE" ] || { echo "REFUSED: base dtb $BASE not present (builder artifact)"; exit 2; }
[ -f "$BUNDLE" ] || { echo "REFUSED: dtbo bundle $BUNDLE not present (builder artifact)"; exit 2; }
echo "dtbo-apply-check: tooling present but full apply-verify not implemented in phone skeleton (ch.03 S40)"
exit 2
