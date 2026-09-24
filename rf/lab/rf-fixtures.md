# rf-fixtures.md -- RF lab fixture inventory (rf-lab-spec S2/S4 + carrier-lab-handbook S3)
# Owner: RF lab. Fixture photo per bench. ASCII only.

## Shielding

- shield_box: TODO-ID (>=80dB isolation to 6GHz, door-switch interlock logged; verdict environment)
- box_verification: weekly (empty box + coupled antenna, callbox sweep -50 -> -110 dBm,
  DUT follows +-3dB, drops cleanly below sensitivity; curve -> rf/<sku>/box-check/)
- shield_bags: handling aids ONLY, never verdict chambers; receipt + monthly phone-inside
  call-drop test (sealed bag + callbox -80 dBm must drop within 30s or bag FAILED);
  labels PASS <date> / FAIL; failed bags destroyed, never downgraded to storage
- dut_placement: fixtured (cradle marks + photo per SKU); hand-holding during radiated takes
  forbidden; door-open event auto-FAILs the take

## Callbox

- asset: TODO (e.g. CMW500/UXM, asset tag + cal sticker current or runs tagged UNCALIBRATED)
- profiles: rf/profiles/ (callbox profile hash MUST match host per-carrier profile hash or run void)
- carrier_approval: carrier-specific profiles run only on carrier-blessed FW
  (see carrier/<id>/modem-fw.json); mismatched FW + profile voids the run

## Band-lock profiles

- dir: rf/lab/band-profiles/ (lock commands + expected MCC/MNC + fallback-unlock procedure)
- rule: every locked run names its profile; unlocked runs state UNLOCKED explicitly

## Cable / attenuator set

- conducted_chain: cabled to modem test port via calibrated attenuator; chain loss measured
  per band at session start (coupler + cable + attenuator, dB); unrecorded loss voids sensitivity
- base_loss_table: rf/cable-loss.csv (+ dated per-band loss table per session)
- calibration_stickers: current or runs tagged UNCALIBRATED

## Booking (carrier-lab-handbook S3)

- entry: rf/lab/CALENDAR-TEMPLATE.md names unit + rig + SIM identity + expected return state
- soak: DO-NOT-TOUCH tags physical + calendar
- fixture_failures: exit 2 infra-flake (callbox power-loss mid-soak extends booking, never silent retry)
