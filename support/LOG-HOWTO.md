# LOG-HOWTO
Collect UART + `dmesg` + `logcat -b all` after repro.
Save under `logs/` as `<date>-<sku>-<issue>.txt`.
Redact before upload: strip IMEI, IMSI, MAC, phone numbers.
Never post raw logs with IMEI to public trackers.
Keep one good-boot log per SKU for diffing.
Builder keeps full logs; phone keeps redacted copies.
See ch.11 §8 triage flow for upload path.
