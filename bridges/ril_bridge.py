"""halide RIL->MM bridge (host owns modem, Android is client).

Android RIL daemon sends single-line requests; host translates to
ModemManager operations. No dual-master: host may reject with DENIED
when radio is draining/shutting down. <5MB RSS, stdlib only.
"""
VALID_ACTIONS = frozenset({
    "DIAL", "HANGUP", "SMS_SEND", "DATA_ENABLE",
    # ch.07 §26: USSD + SS share the modem control channel (ss_ussd_mutex, 30s watchdog).
    "USSD_START", "USSD_RESPOND", "USSD_CANCEL",
    # ch.07 §26: SS queries read-only v1 (set flows refused until carrier evidence filed).
    "SS_QUERY",
    # ch.07 §24: PIN/PUK forward with rate limit (PIN 1s, PUK 2s) + conservative counter.
    "PIN_VERIFY", "PUK_VERIFY",
    # ch.07 §28: registration (numeric PLMN only — names lie) + slave switches.
    "REGISTER_AUTO", "REGISTER_PLMN",
    # ch.07 §22/§20: DATA_ROAMING_SLAVE + hotspot slave (host MM decides, Android mirrors).
    "DATA_ROAMING_SLAVE", "HOTSPOT_SLAVE",
})

SS_QUERYABLE = frozenset({"CFU", "CFB", "CFNRY", "CFNRC", "CWN", "CLIP", "CLIR_Q"})

class RadioState:
    READY = "READY"
    DRAINING = "DRAINING"  # shutdown/OTA — freeze new MO, queue message
    OFF = "OFF"

_state = {"radio": RadioState.READY}
# ss_ussd_mutex: SS and USSD share one control channel; the 30s deadlock watchdog
# (tests/ss-flows.sh §2) watches this session. Single-threaded bridge serializes
# access; USSD_BUSY is returned when a session is already open (ch.07 §26).
_ussd_session = {"open": False}
_last_pin_attempt = {"t": 0.0}
_last_puk_attempt = {"t": 0.0}

def set_radio(s: str) -> None:
    _state["radio"] = s

def handle(line: str) -> str:
    parts = line.strip().split(" ", 1)
    if not parts or not parts[0]:
        return "ERR empty\n"
    action = parts[0].upper()
    if action not in VALID_ACTIONS:
        return "ERR unknown-action\n"
    if _state["radio"] != RadioState.READY:
        return "ERR DENIED-radio-not-ready\n"
    arg = parts[1] if len(parts) > 1 else ""
    if len(arg) > 512:
        return "ERR too-long\n"
    # Per-verb validation (plan-faithful guards; real host calls mmcli/qmicli here).
    if action == "USSD_START":
        if _ussd_session["open"]:
            return "ERR USSD-busy\n"
        if not arg or len(arg) > 32:
            return "ERR bad-arg\n"
        _ussd_session["open"] = True
        return "OK queued:USSD_START\n"
    if action == "USSD_RESPOND":
        if not _ussd_session["open"]:
            return "ERR no-session\n"
        return "OK queued:USSD_RESPOND\n"
    if action == "USSD_CANCEL":
        _ussd_session["open"] = False
        return "OK queued:USSD_CANCEL\n"
    if action == "SS_QUERY":
        if arg.split(" ")[0] not in SS_QUERYABLE:
            return "ERR read-only-v1\n"
        return "OK queued:SS_QUERY\n"
    if action in ("PIN_VERIFY", "PUK_VERIFY"):
        import time
        now = time.monotonic()
        key = "t"
        last = _last_pin_attempt if action == "PIN_VERIFY" else _last_puk_attempt
        gap = 1.0 if action == "PIN_VERIFY" else 2.0
        if now - last[key] < gap:
            return "ERR rate-limited\n"
        last[key] = now
        if not arg.isdigit() or not (4 <= len(arg.split(" ")[0]) <= 8):
            return "ERR bad-arg\n"
        return f"OK queued:{action}\n"
    if action == "REGISTER_PLMN":
        if not arg.isdigit() or len(arg) not in (5, 6):
            return "ERR bad-arg\n"  # numeric mccmnc only (ch.07 §28)
        return "OK queued:REGISTER_PLMN\n"
    if action == "DATA_ROAMING_SLAVE":
        if arg not in ("on", "off"):
            return "ERR bad-arg\n"
        return "OK queued:DATA_ROAMING_SLAVE\n"
    if action == "HOTSPOT_SLAVE":
        if arg not in ("on", "off"):
            return "ERR bad-arg\n"
        return "OK queued:HOTSPOT_SLAVE\n"
    # Real host would call mmcli/qmicli here; phone skeleton echoes intent.
    return f"OK queued:{action}\n"
