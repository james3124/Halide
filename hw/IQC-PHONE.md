# IQC-PHONE.md — incoming quality control per unit (ch.02 §16, 20 minutes)
**Owner: Lab-kept · Phase: all — signed + filed per unit serial before any HALIDE flash**

Station: bench with calibrated meter (§13), lux meter, USB-PD tester, magnifier, ESD mat.

## Checks (5 blocks; block fails = STOP, no flash)

1. **Visual** — cracks, swollen battery, corroded USB-C pins. Photo any defect.
2. **Stock boot + radios** — record stock build fingerprint + modem FW (oracle baseline §13); `qmicli --dms-get-ids` redacted; `iw wlan0 scan` ≥3 SSIDs; BT `show`.
3. **Backup before flash** — GPT + persist/EFS backup; verify restorability by checksum, not file presence. `fastboot getvar all` archived.
4. **Sensors + touch** — `iio_info` non-empty; accel changes on tilt; touch 10-finger `evtest`.
5. **Battery + panel** — design vs `full_charge_capacity`; charge to 100% + 10-min idle drain sanity; 5-point nits + dead-pixel solid-color screens + 240fps flicker check (ch.03 §13).

## Expected (each block)

```
Expected: backup checksum verified OK · evtest 10 slots clean · scan ≥3 SSIDs
```

## Disposition

- PASS → traveler system (ch.02 §17), row appended to `hw/iqc-log.csv`.
- CONDITIONAL → usable with named limitation + BUG link.
- FAIL → quarantine shelf + photo + RMA loopback (ch.02 §18).

Fail action: skipped-IQC unit that later bricks is training material in the monthly flash-log/IQC review.
