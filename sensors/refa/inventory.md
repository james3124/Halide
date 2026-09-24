# REF-A sensor inventory (ch.04 §10, batch records §32)

| sensor | type | range | resolution | power | wake | fifo_depth | max_batch_s |
|---|---|---|---|---|---|---|---|
| accel | accel | ±8g | 0.98mg | 0.14mA idle | non-wake | 512 | 10 |
| gyro | gyro | ±2000dps | 0.06dps | 0.9mA idle | non-wake | 256 | 5 |
| mag | mag | ±4900µT | 0.15µT | 0.08mA idle | non-wake | 128 | 10 |
| prox | proximity | 0-10cm | 1 step | 0.05mA | wake (power: 0.05mA poll) | none | 0 |
| step | step-counter | - | 1 step | 0.02mA | wake (power: 0.02mA AP-hub) | 64 | 30 |

FIFO preferred (§32); prox/step poll via AP hub. Calibration per sensors/refa/layout.md.
