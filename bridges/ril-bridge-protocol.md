# Bridge Protocol: halide-ril-bridge
**Parent: ch.05 §9, ch.07 · Owner: Telephony/Platform · Version: v1**

## 1. Parties & transport

Host daemon `halide-ril-bridged` (Rust, `CAP_NET_ADMIN` dropped after NM handle bind — runs as `halide-radio` user in `halide-bridges` group) ↔ container peer `rild-halide` shim (sends Android-side events) over UNIX STREAM socket `/run/halide/ril-bridge.sock` (`0660 root:halide-bridges`, `SO_PEERCRED` allowlist: container `radio` UID-mapped only).

Framing: length-prefixed (u32 BE length + protobuf `RilEnvelope`, schema in `bridges/proto/ril_bridge.proto`, version field `proto_v=1` — unknown fields rejected, version mismatch closes with `VERSION_MISMATCH` audit line, never best-effort parse).

## 2. Message catalog (normative)

Host→Container (`RadioStateEvent`): `REG_STATE {registered, rat (LTE/WCDMA/GSM/NR), operator_long/short, mcc_mnc, signal_dbm, bars_0_4, data_attached}`, `CALL_STATE {IDLE/RINGING/OFFHOOK, number_redacted_log_only, call_id}`, `SMS_RX {pdu_hash, sender_redacted, body_len, timestamp, slot}` (body carried only with `with_body=true` where Android app holds `RECEIVE_SMS` grant — else metadata-only + fetch-on-demand), `DATA_Bearer {apn, ip, dns, metered}`, `AIRPLANE {on}`.

Container→Host (`HostRequest`): `DIAL {callee, emergency_flag}`, `HANGUP {call_id}`, `ANSWER {call_id}`, `SEND_SMS {dest, body, len}` → host routes via MM and replies `SmsResult {OK/msg_id | ERROR {RADIO_OFF|NO_SIM|NETWORK|TOOLONG}}`, `DATA_REQUEST {apn}` (advisory — host decides), `SIGNAL_POLL` (rate-limited 1/2s, excess returns cached + `RATE_LIMITED` counter metric).

## 3. State machines

Call (host authoritative): `IDLE --MM-dial/MO-request--> DIALING --RINGING--> ACTIVE --hangup--> IDLE`; every transition timestamped both sides; skew >2s raises `CALL_SKEW` metric + journal line (Phase-3 mirror requirement ch.07 §2). MT: MM ring → bridge forwards RINGING ≤1s → GNOME Calls rings AND Android notified (host dialer answers; Android side marked `MISSED-unless-host-answered` — no dual-answer race).

SMS dedupe: PDU SHA256 + 60s window (ch.07 §13); duplicate delivery from modem retransmit returns cached `msg_id` without re-inserting to either store.

Airplane: host `rfkill` event → `AIRPLANE{on}` broadcast + container `ril.setAirplaneMode` forced (container toggle without host = rejected `PERMISSION_DENIED`, ch.05 §9).

## 4. Error handling & backpressure

Max message 64KB (larger → close + `OVERSIZE` metric; SMS bodies never approach it — oversize means bug/attack). Queue depth 128; full → drop-newest `SMS_RX` with `DROPPED_RX` counter (calls never dropped — queue-full during call signaling triggers `PRIORITY_SHED` of data-bearer updates first). Timeouts: request/response 5s; timeout → `TIMEOUT` reply + retry once, then surface to UI ("Radio busy — retry", never infinite spinner). Modem reset (`mmcli --reset`) → bridge emits `RADIO_RESTARTING`, queues MO requests 30s, then replays registration sequence (no lost-dial without callback).

## 5. Security notes

No IMSI/IMEI/number plaintext in committed logs (`halide-log-collect --redact` covers this socket's journal tag). `SEND_SMS` requires Android `SEND_SMS` grant mapped via permission-bridge (ch.05 §9 mapping table) — ungranted package gets `PERMISSION_DENIED`, not silent queue. Fuzz harness `fuzz_ril_parser` (libFuzzer, corpus in `bridges/fuzz/ril/`) runs 10-min per MR (ch.08 §10).

## 6. Contract test (CI)

`bridges/tests/ril_contract.sh`: fake MM (python stub emitting canned `REG_STATE`/call/SMS) + fake container peer asserting: registration mirror ≤2s, MO dial→RINGING→ACTIVE→HANGUP sequence, SMS dedupe (same PDU twice = one insert), airplane propagation both directions, oversize rejection. 20 iterations, 0 desync to pass.

## Verification

- [ ] Contract test green; `RilEnvelope` schema versioned; fuzz smoke green.
- [ ] Call-skew metric <2s p99 over 20-call loop; SMS dedupe proven with retransmit fixture.
