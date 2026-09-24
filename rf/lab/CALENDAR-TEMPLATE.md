# CALENDAR-TEMPLATE.md -- lab bench booking entry (carrier-lab-handbook S3)
# Copy one block per booking into rf/lab/CALENDAR.md (owner: QA/leasing per ch.10 S18).
# ASCII only.

## Booking TODO-YYYY-MM-DD

- unit: TODO (label + serial)
- rig: TODO (box ID / callbox profile / conducted vs radiated)
- sim_identity: TODO (iccid-last4 + carrier; binding changes logged with timestamp + reason + operator)
- band_lock_profile: TODO (or UNLOCKED explicitly)
- expected_return_state: charged >=60%, TODO
- soak_DO_NOT_TOUCH: TODO (yes/no + physical tag ref)
- pre_session_checklist: box verification current / conducted loss measured / callbox self-test pass /
  host<->callbox profile hashes match / FW version recorded / interferer states set per
  rf/lab/interferers.md (missing item ABORTS the session; backfilled checklists = failed runs)
