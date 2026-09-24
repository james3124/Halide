# Blessing campaign log TEMPLATE -- carrier/<id>/blessing-<date>.md (ch.07 S18)
# Copy per campaign. Blessing checklist: all green or UNTESTED-bold (S11 vocabulary).
# ASCII only. No blessing claimed by filling the header -- only by green gates + log links.

carrier: TODO
sku: TODO
date: TODO-YYYY-MM-DD
tester: TODO
sim_sku: TODO (lab SIM; binding logged per carrier-lab-handbook S2)
modem_fw: TODO (version + SHA; FW change expires blessing to STALE-FW per S23)
cell_bands: TODO
ambient_anomalies: TODO

## Checklist (pass/fail + log link each)

- [ ] attach-timing 3 runs (S6 <=90s gate): TODO
- [ ] 20/20 calls + 50/50 SMS (Phase-3 gate): TODO
- [ ] airplane-recovery <=60s x5: TODO
- [ ] 1h soak (S6) + 8h idle (S6): TODO
- [ ] SMSC behaviors (normalization + retry + reports-capability): TODO
- [ ] MMS 3x3 (smsc S2): TODO
- [ ] OTP 2 flows (redacted): TODO
- [ ] STK basic menu walk (best-effort result recorded): TODO
- [ ] roaming-SIM swap (border fixture where available, S16 hysteresis): TODO
- [ ] emergency-status (VERIFIED-with-blessing or UNTESTED -- S10 protocol): TODO

## Close-out

verdict: TODO (blessed / conditional-<id> / fail-<id> with re-test scope)
re_blessing_triggers: modem-fw change | RIL/bridge change on call/SMS paths |
  carrier VoLTE/CSFB policy notice | 6-month age (abbreviated: attach + 5 calls + 10 SMS + soak;
  full campaign annually)
published_to: release notes CARRIERS line + ch.10 D2 radio dashboard (fw-split)
