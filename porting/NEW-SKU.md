# NEW-SKU porting
Ref: ch.11 §8 bring-up sequence.
Week1: add `kernel/devices/<sku>/sku.fragment` + DTS stub.
Week2: map regulators/sensors/audio from vendor dumps.
Week3: first builder boot to fastboot + UART log in `logs/`.
Week4: ril/audio/camera smoke, carrier-lint + regulator-audit PASS.
Copy `telephony/carrier/` template for new MCC/MNC rows.
Run `sh scripts/carrier-lint.sh` and `sh scripts/regulator-audit.sh`.
Keep `super <=6GiB`, `host <=2.2GiB` budgets (see budget-check).
No dd on phone; flash only from builder via assemble plan.
File logs redacted (strip IMEI) per `support/LOG-HOWTO.md`.
Mark SKU done when jobs-mr PASS on builder image.
