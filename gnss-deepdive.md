# GNSS Deep-Dive — From Modem PDS to Both Maps Apps
**Parent: ch.04 §10, ch.07 · Owner: Telephony/BSP · Gate: cold ≤120s / warm ≤30s open sky**

## 1. Signal path (every hop named — GNSS bugs hide in unnamed hops)

Antenna (shared with Wi-Fi/BT on most SKUs — coexistence note ch.04 §12 applies) → modem GNSS engine (QMI PDS services: `PDS_GET_GPS_SERVICE_STATE`, position reports) → host QMI-PDS client (owns the fix loop, 1Hz) → `/run/halide/gnss.nmea` (single NMEA truth) → (a) Phosh Maps via `geoclue` NMEA source, (b) Android `IGnss@2.1` shim republishing `GnssLocation` + NMEA (ch.04 §10). AGPS: SUPL server from carrier profile (ch.07 §11 `profile.json` + provider-info fallback); offline-first fix required (SUPL-unreachable TTFF measured separately — the "no data in the mountains" case is a gate, not an edge).

## 2. Bring-up ladder (host first, then shim — same discipline as modem)

1. `qmicli --pds-get-gps-service-state` → service READY (else modem-GNSS firmware/config — stop, fix here).
2. NMEA flows at 1Hz with `$GPGSV` satellite visibility (count sats, not just fix — 0 sats = antenna/RF path, ≥6 no-fix = engine/config).
3. Cold fix open sky ≤120s (battery-backed ephemeris cleared via PDS reset for true cold; record method — fake-cold numbers are a classic lie).
4. Warm fix ≤30s (ephemeris <2h old, same location ±50km).
5. Host Maps navigates 15-min route (position stability: no >30m jumps; jump log from NMEA diff).
6. Android GPSTest side-by-side: same fix ±5s, same sat count ±1 (ch.04 §10 shim proven, not assumed).
7. Urban-canyon + indoor-graceful notes (accuracy degrades documented, no fix-claim where none).

## 3. Interference & coexistence tests

Wi-Fi scan storm during fix (scan every 5s × 10 min — TTFF regression recorded), BT A2DP streaming during track (position jump count vs quiet baseline), LTE upload saturating during fix (PA harmonics desense check on shared-antenna SKUs — fail here means antenna-tuning issue filed against HW, not a software workaround). Results per SKU in `gnss/<sku>/coexist.md`.

## 4. Power & duty discipline

GNSS engine off unless a client holds a fix request (wakelock audit: `gps` wakeup-source must be 0 overnight with no nav running — ch.10 §8 residency gate includes this). Batching: nav-active 1Hz, background-geofence 0.1Hz (configurable, documented power delta per rate measured once per SKU).

## Verification

- [ ] Cold/warm TTFF with method notes + AGPS on/off matrix; 15-min nav track vs stock GPX overlay archived; coexistence deltas recorded.
