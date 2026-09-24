"""halide alarm bridge (RTC wake + time-vote re-fire, host side).

Alarms survive DST/suspend/time-jump: the host RTC is the wake source and
halide-time-vote (debian/scripts/halide-time-vote) re-arms both stacks after
any step. The alarm path never waits for NTP (fires on RTC match even in
CLOCK_HOLDOVER, ch.05 section 29).

Transport note: this bridge drives RTC + D-Bus org.halide.Alarm and the
prop-allowlist channel; it opens NO unix socket of its own. If a dedicated
socket is ever wanted, register it in bridges/SOCKETS.md first (ch.05
section 10: undocumented socket = do not ship) and mirror the row in
bridges/BOUNDARIES.md.

Protocol (in-process text twin, stdlib only, <5MB RSS):
  REQ: "SET_ALARM <epoch> <label>\\n" | "CANCEL <id>\\n" | "LIST\\n"
  RESP: "OK alarm:<id>\\n" | "OK cancelled:<id>\\n" | "OK count:<n>\\n"
         | "ERR <reason>\\n"
"""
import time

_alarms: dict = {}
_next_id = [1]

def _valid_epoch(tok: str):
    try:
        v = int(tok)
    except ValueError:
        return None
    now = int(time.time())
    # RTC_SUSPECT window (ch.05 section 29): pre-2026 / post-2040 rejected.
    if v < 1767225600 or v > 2524608000:
        return None
    if v < now - 86400:
        return None
    return v

def handle(line: str) -> str:
    parts = line.strip().split(" ", 2)
    if not parts or not parts[0]:
        return "ERR empty\n"
    cmd = parts[0].upper()
    if cmd == "SET_ALARM" and len(parts) == 3:
        epoch = _valid_epoch(parts[1])
        label = parts[2]
        if epoch is None:
            return "ERR bad-epoch\n"
        if len(label) > 128 or not label:
            return "ERR bad-label\n"
        aid = _next_id[0]
        _next_id[0] += 1
        _alarms[aid] = (epoch, label)
        return f"OK alarm:{aid}\n"
    if cmd == "CANCEL" and len(parts) == 2:
        try:
            aid = int(parts[1])
        except ValueError:
            return "ERR bad-id\n"
        if aid not in _alarms:
            return "ERR unknown-id\n"
        del _alarms[aid]
        return f"OK cancelled:{aid}\n"
    if cmd == "LIST" and len(parts) == 1:
        return f"OK count:{len(_alarms)}\n"
    return "ERR bad-command\n"
