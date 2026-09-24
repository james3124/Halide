# GNSS coexistence per SKU (gnss-deepdive s3) - refa TEMPLATE
# Antenna shared Wi-Fi/BT on most SKUs (ch04 s12 applies; see hw rf-path).
# wifi_scan_storm: scan every 5s x 10min during fix. TTFF_regression=TODO-measured.
# bt_a2dp: streaming during track. jump_count_vs_quiet=TODO-measured.
# lte_upload: saturating during fix (PA harmonics desense, shared-antenna SKUs).
#   Fail here = antenna-tuning issue vs HW, not software workaround. TODO-measured.
# Per-rate power delta (nav 1Hz vs geofence 0.1Hz): TODO-measured mA.
# Status: UNMEASURED.
