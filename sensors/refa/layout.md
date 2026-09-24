# Sensors mount layout (text-only)
- Mount matrix: identity stub; update per-device rotation here.
- Axes map per sensor in driver DT; keep matrix + DT in sync.
- Batch ref: sensors/refa/batch.conf governs FIFO batch timeouts.
- Orientation check: 6-face rotation test before sign-off.
- Ref ch. sensors; no calibration binaries here.
- Owner: sensors bring-up; stamp unit serial on change.
- Fail action: mismatch = block CTS sensor tests; magnetometer offsets per SKU next.
