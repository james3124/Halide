# OQC checklist -- outgoing quality control (every shippable unit, before box).
# OQC runs after the traveler smoke table is green; OQC is the ship/no-ship gate.
# ASCII only.

Traveler ID: TRV-____ | SKU: ____ | Date UTC: ____ | Inspector: ____

- [ ] Traveler smoke table 100 pct green (or unit quarantined with bug ID, not here).
- [ ] AVB state green via avbtool info_image (flag 2, prod key, monotonic rollback).
- [ ] ro.boot.verifiedbootstate reads green (orange/yellow = dev-only + warning sticker).
- [ ] MACs verified against hw/<sku>/mac-range.txt allocation, no duplicates.
- [ ] Sticker fields complete (SKU, serial, halide-v version, support URL, reg marks).
- [ ] Traveler scan redacted (no IMSI/IMEI in retained PDF) and filed under
      factory/travelers/<serial>.pdf (retention 180 days confirmed).
- [ ] Slot check: A/B both bootable (bootctl status), standby rollback image present
      (stranded-brick guard; provision-reset.sh logic mirrored on the bench).
- [ ] Nightly watermark absent (release images only; DONOTUSE-daily never ships).

Verdict: SHIP / QUARANTINE (bug: ____)  Sign: ____ QA spot-check: ____
