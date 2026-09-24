#!/bin/bash
# sign-kernel.sh — kernel Image + .ko signing ceremony wrapper (ch.03 S24, ch.08 S8, ch.09 S15).
# PHONE-SAFE: signing happens ONLY on the air-gapped offline signer with 2-of-3 custodian quorum;
# this wrapper refuses everywhere else. Heavy-op guard copies build-all.sh thresholds.
set -eu
cd "$(dirname "$0")/.."

MEM_GB=$(free -g | awk '/^Mem:/{print $2}')
AVAIL_DISK_GB=$(df -BG . | awk 'NR==2{gsub("G","",$4); print $4}')

refuse() { echo "REFUSED: $1"; exit 2; }

# ceremony markers (ch.08 S8 / ch.09 S15): HSM key handle + custodian quorum roster + offline hint
[ -n "${HSM_KERNEL_KEY:-}" ] || refuse "HSM_KERNEL_KEY env unset — keys live in HSM, never in git"
[ -f keys/custodians.md ] || refuse "keys/custodians.md absent — 3-named/2-of-3 quorum roster must be committed"
[ "${SIGNER_AIRGAP_CONFIRM:-}" = "yes" ] || refuse "run on the offline signer only (no Wi-Fi/BT hardware, ch.08 S19); set SIGNER_AIRGAP_CONFIRM=yes on that host"
[ "$MEM_GB" -ge 16 ] || refuse "need >=16GB RAM (have ${MEM_GB}GB) — builder thresholds per README.phone-build.md"
[ "$AVAIL_DISK_GB" -ge 400 ] || refuse "need >=400GB free (have ${AVAIL_DISK_GB}GB)"

# Real ceremony (ch.03 S24): sign Image, then every .ko in depmod order
# (scripts/sign-file sha512 $KEY cert.x509 module.ko), regen depmod POST-sign, write
# PROVENANCE.txt (source SHA, fragment SHAs, toolchain, timestamp, key-id, vermagic).
echo "ceremony markers present — full signing flow not implemented in phone skeleton (ch.09 S15)"
echo "quorum reminder: two custodians, verbal fingerprint check, transparency entry + anomalies-or-none"
exit 2
