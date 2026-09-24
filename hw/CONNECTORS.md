# CONNECTORS.md — connector/cable qualification list (ch.02 §27)
**Owner: Lab-kept (QA row) · Phase: all — reviewed quarterly with ch.02 §13 upkeep**
Single source of truth. Gate measurements run on GOLDEN accessories only; unqualified-accessory measurements carry `ACCESSORY-UNQUALIFIED` and cannot gate (ch.02 §21).

## Ports on REF-A (per ch.02 connector table)

| Port | Type | Notes |
|---|---|---|
| USB-C (bottom) | USB 3.1 gen1 + PD, dual-role | `dwc3-qcom`; charging-only default until user selects (ch.08 §10) |
| 3.5mm jack | CTIA wired audio | shares codec path with WCD; loopback gate per ch.04 §30 |
| SIM tray | nano-SIM single-active v1 | tray-wear log after 50 swaps (ch.02 §20) |
| UART test point | 1.8V, board-side pads `ttyMSM0` 115200 8n1 | adapter pairing `A1-UART`; never hot-plug ungrounded |
| Pogo / U.FL | RF test ports | untested test-ports don't exist for bring-up (ch.02 §20) |

## APPROVED accessories (acceptance evidence in hw/cable-log.csv §21)

| Class | Part / serial | Evidence |
|---|---|---|
| USB-C cable | CBL-GOLDEN-01/02/03 | continuity + CC both orientations + 10× getvar + boot.img transfer + PD-profile-vs-label |
| Charger | CHG-GOLDEN-01/02 | PD meter: loaded-rail sag ≤5% under phone load |
| UART adapter | UART-GOLDEN-01/02 | loopback 115200 8n1 + driver-version pin + archived `tio --log` sample |

## RETIRED (DESTROY-labeled, never re-enter circulation)

| Serial | Failure mode |
|---|---|
| CBL-RET-014 | CC resistor lie — orientation-dependent fastboot failures |

Expected: flash-log cable serials join this list monthly; >2 attributed failures/quarter = auto-retire + vendor scorecard entry (ch.02 §18).

Fail action: missing golden set row = lab audit FAIL (ch.11 §26 shelf check).
