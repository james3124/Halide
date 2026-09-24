# ril-mm-mapping.md -- ril-bridge <-> ModemManager mapping complement (ch.07 S1, ch.05 bridges/ril)
# Host owns the modem. ModemManager + NetworkManager authoritative for registration,
# voice, SMS, data bearers. Android RIL is a client of the bridge, never a second master.
# This file maps bridge verbs to host MM operations. It does NOT change bridge code.
# DO NOT EDIT hybrid/bridges/ril_bridge.py or SOCKETS.md from this area (report below).
# ASCII only.

## Current bridge verbs (bridges/ril_bridge.py VALID_ACTIONS) -> host MM op

| Bridge verb | Host MM operation (host executes) | Notes |
|---|---|---|
| DIAL <number> | mmcli -m <m> --voice-create-call="number=<E.164>" | emergency numbers rerouted per telephony/emergency-routing.conf (host dialer always) |
| HANGUP | mmcli -m <m> --voice-hangup-all (or per-call hangup) | hangup-cause QMI code logged to voice-quality record |
| SMS_SEND | halide-smsd submit -> MM --messaging-create-sms | bridge never hand-crafts TP-DUs; state machine in telephony/sms-policy.conf |
| DATA_ENABLE on/off | NM gsm bearer up/down (MM --simple-connect / --simple-disconnect) | bearer pre-check via qmicli --wds-get-packet-service-status; no double-start |

## Radio-state gate (bridge-side, mirrored from host)

READY = accept; DRAINING/OFF = reject ERR DENIED-radio-not-ready.
DRAINING freezes new MO dials with "Radio restarting" (queued 30s); SMS >60s old needs
user confirm on replay (stale-text guard, ch.07 S15).

## Proto parity (bridges/proto/ril_bridge.proto)

Signal/Registration/CallState/SmsFrame mirror host truth with <=2s lag (timestamped
host-signal.log vs dumpsys telephony.registry diff). Registration.plmn is numeric
mcc-mnc only (names lie on border cells, ch.07 S28). slot_id reserved-and-populated
from day one for Phase-4 DSDS (ch.07 S19); v1 reports single slot truthfully.

## NEEDED BRIDGE ADDITIONS (report -- telephony area must not edit bridges/)

1. USSD verbs: USSD_START/USSD_RESPOND/USSD_CANCEL translating MMI-shaped dial strings
   (regex ^[*#].*[#]$ + *#06# offline IMEI-display special case) to MM
   --3gpp-ussd-initiate/respond/cancel; single-session serialization with SS (shared
   ss_ussd_mutex + 30s deadlock-watchdog logging SS-DEADLOCK, ch.07 S25/S26).
2. SS verbs (query-only v1): SS_QUERY_CF / SS_QUERY_CW mapping to MM
   Modem3gppUssd/ModemVoice supplementary-service D-Bus (or qmicli --voice-* fallback
   per telephony/refa/ss-path.md). Set-flows stay disabled v1 (tests/ss-flows.sh
   asserts disabled; enabling needs carrier-acceptance evidence).
3. SMS status mirror: SMS-STORAGE-FULL -> Android SmsManager RESULT_NO_MEMORY
   (fake-success here loses 2FA codes, ch.07 S31).
4. DATA_STALL mirror states: SUSPECT/FROZEN-arrows per telephony/data-stall-policy.conf
   T+0 step (bars stay, activity arrows freeze + "..." badge, never fake animation).
5. PIN/PUK forward verbs: container PIN dialog input forwarded to MM verify/unblock
   (never verified locally; single-counter rule, telephony/sim-pin-puk.conf) with
   1 verify/2s bridge rate limit (excess returns RATE-LIMITED locally, ch.07 S27).
6. Manual-PLMN + roaming verbs: REGISTER_AUTO / REGISTER_PLMN / DATA_ROAMING_SLAVE
   (container toggle without host = rejected + explained, ch.07 S16/S28).
7. Hotspot slave: hotspot toggle slaved to NM (container toggle without host bearer =
   rejected + explained, ch.07 S24).
8. USSD_BUSY on second concurrent session; SESSION-ABORTED on airplane/SIM-pull
   mid-session; CALL-UNKNOWN on dial-timeout (query call-info 2x, banner, never fake).

## Verification

- tests/ss-flows.sh: ss-ussd-lock declared (item 1 mutex), set-flows disabled-v1.
- Bridge desync check (ch.07 S8 row): Android No-Service while host OK -> restart
  bridge only (not container), file bug with both logs.
