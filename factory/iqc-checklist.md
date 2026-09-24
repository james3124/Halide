# IQC checklist -- incoming quality control (boards, panels, batteries, accessories).
# Fail = lot hold + supplier note, never silent sort-and-ship. ASCII only.

Lot: ____ | Supplier: ____ | Date UTC: ____ | Inspector: ____
Ref: hw/IQC-PHONE.md (acceptance criteria), hw/cable-log.csv (accessories).

- [ ] Packing vs PO: quantities, part numbers, panel variants match (mismatch = hold).
- [ ] Visual: no cracked panels, no bent frames, connector pins straight (CONNECTORS.md).
- [ ] Board revision matches hw/refa/inventory.md expectation for this lot.
- [ ] Sample boot on lab-runner (testkey/eng only): UART alive, no panic in first log.
- [ ] Accessories (cables/chargers): GOLDEN-vs-lot continuity + CC both orientations
      (unqualified-accessory measurements carry ACCESSORY-UNQUALIFIED, never gate).
- [ ] Serials recorded in hw/refa/inventory.md style (stub serials replaced, no real
      serials pre-printed in bulk; IMSI/IMEI/ICCID never bulk-printed).
- [ ] iqc-log.csv line appended (lot, sample size, accept/reject per AQL table).

Verdict: ACCEPT / HOLD (reason: ____)  Sign: ____
