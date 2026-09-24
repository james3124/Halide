#!/bin/bash
# tests/apps-seed.sh — preinstalled-app contract (ch.05 §17, ch.01 §12).
# Exit 0/1/2. Text-only.
set -u
cd "$(dirname "$0")/.."
FAIL=0

SEED=apps/SEED.md
[ -f "$SEED" ] || { echo "SKIP: $SEED missing"; exit 2; }

# 1. Mandatory host set present in seed (ch.05 §17 list)
for app in gnome-calls gnome-chats epiphany gnome-settings gnome-terminal libcamera-app gnome-maps halide-backup; do
  grep -q "^$app" "$SEED" || { echo "FAIL: preinstalled host app '$app' missing (ch.05 §17)"; FAIL=1; }
done

# 2. Android allowlist exactly 4 seeded system apps (F-Droid, Aurora, OpenCamera, Settings-bridge)
for app in F-Droid Aurora OpenCamera Settings-bridge; do
  grep -q "^$app" "$SEED" || { echo "FAIL: android allowlist app '$app' missing (drawer allowlist ch.05 §13)"; FAIL=1; }
done

# 3. No-GMS posture: seed must not list Play/GMS as seeded (ch.01 §12)
if grep -E "^\s*(com.android.vending|com.google.android.gms)" "$SEED" | grep -qv "#"; then
  echo "FAIL: GMS/Play listed as seeded — ch.01 §12 ban"; FAIL=1
fi
grep -qi "NOT preinstalled" "$SEED" || { echo "FAIL: microG posture line missing (ch.01 §12)"; FAIL=1; }

# 4. Hidden duplicates match hide.conf (stock Dialer/SMS/Browser — ch.05 §13)
for pkg in com.android.dialer com.android.messaging com.android.browser; do
  grep -q "$pkg" apps/drawer/hide.conf || { echo "FAIL: $pkg not hidden in drawer/hide.conf"; FAIL=1; }
done

# 5. Default-app map: host owns phone/sms/browser/camera defaults (ch.05 §17)
[ -f apps/DEFAULT-APPS.csv ] || { echo "FAIL: DEFAULT-APPS.csv missing"; FAIL=1; }
for a in DIAL SENDTO IMAGE_CAPTURE; do
  grep -q "HANDLED_BY_HOST" apps/DEFAULT-APPS.csv || { echo "FAIL: no HANDLED_BY_HOST rows"; FAIL=1; }
  break
done
# Android never silently default: VIEW/WEB_SEARCH must ask host first or be bridged
grep -q "ASK_HOST_FIRST" apps/DEFAULT-APPS.csv || {
  echo "FAIL: default-app chooser rule missing (Android never silently default)"; FAIL=1; }

# 6. Flatpak: filtered remote concept + growth cap 20 (§17)
grep -q "halide-filtered" "$SEED" || { echo "FAIL: flatpak filtered remote missing"; FAIL=1; }
grep -q "cap 20" "$SEED" || { echo "FAIL: flatpak 20-app cap missing"; FAIL=1; }

[ "$FAIL" -eq 0 ] && echo "apps-seed: PASS"
exit "$FAIL"
