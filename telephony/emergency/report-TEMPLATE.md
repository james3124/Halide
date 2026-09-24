# Emergency call certification evidence TEMPLATE (emergency-call-certification S2)
# Copy to telephony/emergency/<region>-<sku>-<date>.md per tuple. ASCII only.
# No certifications claimed by filling this template -- a row is evidence only when every
# gate below ran on the named unit/box with redacted logs attached. Until then: UNTESTED.
# NEVER commit IMSI/IMEI/ICCID/call-numbers (redact per telephony/log-redaction.conf).

region: TODO (US/EU/UK/JP/AU)
sku: TODO (REF-A/REF-B)
numbers_tested: TODO (e.g. US: 911)
sim_state: TODO (provisioned | expired-zero-balance | no-SIM-SOS-only)
roaming: TODO (Y/N)
modem_fw_ver: TODO-version-string
modem_fw_sha256: TODO (builder-supplied at flash time; never invent)
profile_hash: TODO (carrier/<id>/profile.json short hash)
callbox_or_box_id: TODO
psap_coord_id_or_LAB-ONLY: LAB-ONLY (live rows require written ticket id, S5)

## Execution record (fill per S2 steps)

1. camp_check: TODO (MCC/MNC + band from qmicli --nas-get-serving-system + MM state)
2. setup_time_dial_to_alerting_s: TODO (lab gate <=10s; live <=20s or P1)
3. audio_20s_both_ways: TODO (pass/fail + note)
4. location_indication: TODO (AML/QMI position-fix-sent present/absent; absence logged, never faked)
5. release_cause: TODO (normal cause expected)
6. re_camp_s: TODO (gate <=60s)

## Result

result: UNTESTED (change to PASS/FAIL only with all rows above measured + redacted log linked)
date: TODO-YYYY-MM-DD
tester: TODO
redacted_log: TODO-path (versions, timestamps, setup cause codes only)
lockscreen_5x: TODO (5/5 without unlock bypass, per tuple family)
notes: TODO (ambient anomalies: storms affect radio -- note them)
