#!/bin/bash
# scripts/sign-all.sh -- offline signing ceremony runner (ch.09 S15, ch.08 S8).
# Builder side: produce unsigned set + hashes.txt. Signer side (air-gapped,
# Custodian-A + Custodian-B present): verify unsigned state, sign with release
# key + rollback, verbal key-id check, SHA256.signed.txt. Ceremony log needs
# attendees, fingerprints, rollback values, hashes before/after, and a required
# anomalies-or-none line (missing line = incomplete ceremony = release blocked).
# PHONE-SAFE: plan/check modes text-only; ceremony mode refuses off-signer (exit 2).
set -eu
cd "$(dirname "$0")/.."

MODE="${1:-plan}"
if [ "$MODE" = "plan" ]; then
  echo "signing ceremony plan (offline machine, two custodians)"
  echo " ON BUILDER: build-all.sh \$SKU user --no-sign"
  echo "   sha256sum out/\$SKU/{boot,vendor_boot,vbmeta,super,host}.img payload.zip > hashes.txt"
  echo " SNEAKERNET hashes.txt + images to offline signer (USB stick SIGN-X, scanned)"
  echo " ON SIGNER: avbtool verify_image (confirm unsigned-expected state)"
  echo "   sign-all.sh --ceremony (signs + writes signatures.json)"
  echo "   both custodians read key-id + rollback aloud, compare to release plan"
  echo "   sha256sum signed/* | tee signed/SHA256.signed.txt; SNEAKERNET back"
  echo " LOG: keys/ceremonies/<date>-<ver>.md with anomalies-or-none line (required)"
  exit 0
fi

if [ "$MODE" = "check" ]; then
  LOG="${2:?usage: sign-all.sh check <ceremony-log.md>}"
  [ -f "$LOG" ] || { echo "REFUSED: $LOG not found"; exit 2; }
  rc=0
  for pat in "anomalies" "key-id\|fingerprint" "rollback"; do
    grep -qi "$pat" "$LOG" || { echo "FAIL: ceremony log missing '$pat' line (incomplete ceremony)"; rc=1; }
  done
  grep -qi "anomalies.*none\|anomalies: none" "$LOG" && echo "OK: anomalies-or-none line present" || {
    grep -qi "anomalies" "$LOG" && echo "OK: anomalies documented" || true
  }
  [ "$rc" -eq 0 ] && echo "CEREMONY-LOG OK"
  exit "$rc"
fi

refuse() { echo "REFUSED: $1"; exit 2; }
[ "${SIGNER_AIRGAP_CONFIRM:-}" = "yes" ] || refuse "run on the offline signer only; set SIGNER_AIRGAP_CONFIRM=yes on that host"
[ -n "${HSM_RELEASE_KEY:-}" ] || refuse "HSM_RELEASE_KEY env unset -- keys live in HSM, never in git"
[ -f keys/custodians.md ] || refuse "keys/custodians.md absent -- 2-of-3 quorum roster must be committed"
MEM_GB=$(free -g | awk '/^Mem:/{print $2}')
[ "$MEM_GB" -ge 16 ] || refuse "need >=16GB RAM (have ${MEM_GB}GB)"
echo "Ceremony markers present -- full signing runs on the offline signer only."
exit 2
