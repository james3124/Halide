# rf/refa/coupling.md -- antenna-coupling notes for SKU refa (rf-lab-spec S5)
# Coupling method is part of the verdict. ASCII only. Photos referenced, not embedded.

- coupler_model: TODO + placement photo with mm ruler: TODO-ref
- polarization: TODO
- distance_to_dut_antennas: 10-20mm fixtured gap (NEVER press coupler against antenna;
  near-field detune lies)
- antennas: main / diversity / GNSS / Wi-Fi distances: TODO
- enclosure_variant: TODO (photo of date code -- silent HW revs change RF)
- cable_routing: modem test cables away from GNSS/Wi-Fi antennas; routing photo on change: TODO-ref
- diversity_mimo: TODO (both chains coupled, or explicitly declared SISO with justification)
- phantom: hand/body phantom ONLY for declared SAR-adjacent checks, never sensitivity claims
- change_rule: any coupling change triggers box re-verification (rf-lab-spec S2) before verdict takes
- box_check_log: rf/refa/box-check/ (weekly sweep curve -50 -> -110 dBm, DUT follows +-3dB)
