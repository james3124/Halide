# Appendix 04-A — REF-A HAL Dumps & Golden References
**Parent: ch.04 · Purpose: golden outputs every HAL MR diffs against · Refresh: per release**

## 1. How to capture (exact commands, redacted where noted)

```bash
SKU=sdm845-refa; D=hw/$SKU/dumps/$(date -u +%F); mkdir -p $D
lxc-attach -n android -- service list > $D/service-list.txt
lxc-attach -n android -- dumpsys media.camera > $D/camera.txt
lxc-attach -n android -- dumpsys audio > $D/audio.txt
lxc-attach -n android -- dumpsys sensorservice > $D/sensors.txt
lxc-attach -n android -- dumpsys lights > $D/lights.txt
lxc-attach -n android -- dumpsys vibrator > $D/vibrator.txt
lxc-attach -n android -- dumpsys power > $D/power.txt
lxc-attach -n android -- dumpsys health > $D/health.txt
lxc-attach -n android -- dumpsys telephony.registry > $D/telephony.txt  # redact IDs after
lxc-attach -n android -- dumpsys SurfaceFlinger --latency > $D/sf-latency.txt
tinymix contents > $D/tinymix.txt
qmicli -d /dev/cdc-wdm0 --nas-get-signal-strength > $D/signal.txt
qrtr-lookup > $D/qrtr.txt
halide-log-collect --redact --out $D/redacted-bundle.tar.gz
sha256sum $D/* | tee $D/SHA256.txt
```

`halide-log-collect --redact` strips IMSI/IMEI/ICCID/numbers (regex + QMI TLV denylist); CI asserts no `\b\d{15}\b` (IMEI-length) digit runs survive in committed dumps (false-positive allowlist for sensor IDs documented inline).

## 2. Golden diff rules

`scripts/dump-diff.sh <old> <new>` ignores volatile fields (timestamps, counters, `uptime`, signal dBm ±6dB, battery % ±2) via `dumps/golden-ignore.txt` patterns; everything else must match or the MR explains each hunk (HAL behavior change without dump explanation = review fail). New services appearing in `service-list.txt` require manifest + sepolicy references in the same MR.

## 3. Camera characteristics golden (per sensor)

`dumpsys media.camera` full characteristics archived + human-readable extract (`camera/<sku>/<sensor>.md` per ch.04 §9): `LENS_FACING`, `SENSOR_INFO_*` (size, sensitivity range), `SCALER_STREAM_CONFIGURATION_MAP` (all sizes — v1 gate sizes highlighted), `CONTROL_AE_COMPATIBLE_MODES`, flash `FLASH_INFO_AVAILABLE`. AE/AWB convergence test: 5 scenes (daylight/indoor/low-light/backlit/macro), 3 shots each, record convergence time + lock stability (`CONTROL_AE_STATE` trace) — regressions here are user-visible photo misses, not lab trivia.

## 4. Audio golden

`tinymix.txt` baseline + `dumpsys audio` (streams, volumes, effects) + `audio/<sku>/policy.json` + `call-gains.conf` + `measurements.md` (1kHz sine THD+N plot, frequency-response pink-noise plot proving single-EQ per ch.04 §8). Gain-change MRs attach fresh 5-call log (quiet/street/car/speaker/headset) + both plots or are closed.

## 5. Sensors golden

`dumpsys sensorservice` (all handles, rates, FIFO sizes) + `sensors/<sku>/inventory.md` (range/resolution/power per sensor) + rawproof: 10s `iio` capture per sensor with stimulus noted (tilt/spin/magnet pass/light-cover). Step-counter: 100-step walk, count ±5. Proximity: finger-cover 20×, 0 miss. ALS: 3 lux levels vs meter, ±15%.

## Verification

- [ ] Dump procedure re-runnable by non-author (fresh-eyes quarterly).
- [ ] Golden diff clean on release candidate; every hunk explained or reverted.
