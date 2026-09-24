#!/bin/bash
# tests/drawer-shim.sh — drawer generation contract (ch.05 §13). Exit 0/1/2.
set -u
cd "$(dirname "$0")/.."
FIX=/tmp/halide-drawer-pm.txt
OUT=/tmp/halide-drawer-out
rm -rf "$OUT"; mkdir -p /tmp

# fixture: allowlist app, third-party app, hidden stock app, GMS (must never show),
# duplicate source, disabled app
cat > "$FIX" <<'EOF'
# pkg source [disabled]
org.fdroid.fdroid fdroid
org.wikimedia.wikipedia fdroid user
com.android.dialer aosp
com.google.android.gms aosp
org.thoughtcrime.securesms fdroid user
org.thoughtcrime.securesms aurora
com.example.game fdroid user disabled
EOF

python3 bridges/drawer_shim.py "$FIX" apps/drawer/hide.conf "$OUT" || { echo "FAIL: generator rc"; exit 1; }

FAIL=0
assert_file() { [ -f "$OUT/$1" ] || { echo "FAIL: missing $1"; FAIL=1; }; }
assert_file android-org.fdroid.fdroid.desktop
assert_file android-org.wikimedia.wikipedia.desktop
assert_file android-org.thoughtcrime.securesms.desktop      # duplicate -> one entry
assert_file android-com.example.game.desktop                # disabled -> greyed, not vanish
[ -f "$OUT/android-com.android.dialer.desktop" ] && { echo "FAIL: hidden dialer shown"; FAIL=1; }
[ -f "$OUT/android-com.google.android.gms.desktop" ] && { echo "FAIL: GMS shown (ch.01 §12)"; FAIL=1; }
grep -q "X-HALIDE-Badge=android" "$OUT/android-org.wikimedia.wikipedia.desktop" || { echo "FAIL: badge missing"; FAIL=1; }
grep -q "halide-android-launch" "$OUT/android-org.fdroid.fdroid.desktop" || { echo "FAIL: Exec line wrong"; FAIL=1; }
grep -q "X-HALIDE-Disabled=true" "$OUT/android-com.example.game.desktop" || { echo "FAIL: disabled tag missing"; FAIL=1; }
grep -q "X-HALIDE-Sources=fdroid+aurora" "$OUT/android-org.thoughtcrime.securesms.desktop" || { echo "FAIL: source chip missing"; FAIL=1; }

[ "$FAIL" -eq 0 ] && echo "drawer-shim: PASS"
rm -rf "$OUT"
exit "$FAIL"
