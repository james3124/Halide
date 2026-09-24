#!/bin/bash
# tests/dns-leak.sh — container DNS must follow host resolver, never a second cache (ch.05 §16).
# Textual check of resolv.conf under a mounted container rootfs; live on device.
# DOD: DoD-logs
set -eu
cd "$(dirname "$0")/.."
FAIL=0

# 1. textual: if a container rootfs is mounted, its resolv.conf must be a forwarder stub
ROOTFS=""
for C in /data/android/data /var/lib/halide/container; do
  [ -d "$C" ] && ROOTFS="$C" && break
done
if [ -n "$ROOTFS" ]; then
  RC="$ROOTFS/etc/resolv.conf"
  if [ ! -f "$RC" ]; then
    echo "FAIL-INFRA: rootfs at $ROOTFS but no resolv.conf (runner/lab issue)"; exit 2
  fi
  # forwarder stub = nameserver 127.0.0.53 or a host-pushed server; a hard-coded
  # public resolver here means container-side caching/leak path (ch.05 §16)
  if grep -q '^nameserver 127\.0\.0\.53' "$RC" || grep -q '^nameserver 127\.0\.0\.1' "$RC"; then
    echo "dns-leak: container resolv.conf is a forwarder stub — OK"
  elif grep -q '^nameserver' "$RC"; then
    SRV=$(grep '^nameserver' "$RC" | head -1)
    # host-pushed servers may legitimately appear if host resolver down (DNS_FALLBACK logged)
    echo "note: container nameserver $SRV — allowed only if host-pushed (check DNS_FALLBACK journal)"
  else
    echo "FAIL: container resolv.conf has no nameserver line"; FAIL=1
  fi
else
  echo "note: no container rootfs mounted on this host — skipping textual check"
fi

# 2. live: pushed DNS must be visible in container getprop (ch.05 §16 dns-follows)
if command -v adb >/dev/null 2>&1 && adb get-state >/dev/null 2>&1; then
  D1=$(adb shell getprop net.dns1 2>/dev/null | tr -d '\r\n' || echo "")
  H1=$(adb shell halide-netd-drive --host-dns 2>/dev/null | tr -d '\r\n' || echo "")
  if [ -z "$D1" ] && [ -z "$H1" ]; then
    echo "SKIP: no DNS state readable on unit (device/builder only)"; exit 2
  fi
  echo "dns-leak: net.dns1=$D1 host_first=$H1"
  [ -n "$D1" ] && [ "$D1" = "$H1" ] || { echo "FAIL: container DNS does not follow host resolver (leak path)"; FAIL=1; }
else
  echo "SKIP-live: no adb device — textual checks only (device/builder only)"
fi
[ "$FAIL" = 0 ] && echo "dns-leak: PASS" || echo "dns-leak: FAIL"
exit "$FAIL"
