"""halide AudioFlinger->PipeWire bridge (host side, single consent source).

Android AudioFlinger sends single-line requests; host translates to
PipeWire operations. Call preempts media (ducked). No threads, no deps,
<5MB RSS — safe on 4GB tier phones.

Protocol (unix SOCK_STREAM /run/halide/audio.sock):
  REQ: "ROUTE <node>\\n" | "VOLUME <node> <0-100>\\n" | "MUTE <node>\\n"
  RESP: "OK routed:<node>\\n" | "OK ducked\\n" | "OK volume:<node>:<lvl>\\n"
        | "OK muted:<node>\\n" | "ERR <reason>\\n"
"""
VALID_NODES = frozenset({"media", "call", "alarm"})

_state: dict = {
    "call_active": False,
    "volumes": {"media": 50, "call": 50, "alarm": 50},
    "muted": {"media": False, "call": False, "alarm": False},
}

def handle(line: str) -> str:
    parts = line.strip().split()
    if not parts or not parts[0]:
        return "ERR empty\n"
    cmd = parts[0].upper()
    if cmd == "ROUTE" and len(parts) == 2:
        node = parts[1].lower()
        if node not in VALID_NODES:
            return "ERR bad-node\n"
        if node == "call":
            _state["call_active"] = True
            return "OK routed:call\n"
        if node == "media" and _state["call_active"]:
            return "OK ducked\n"
        return f"OK routed:{node}\n"
    if cmd == "VOLUME" and len(parts) == 3:
        node = parts[1].lower()
        if node not in VALID_NODES:
            return "ERR bad-node\n"
        try:
            lvl = int(parts[2])
        except ValueError:
            return "ERR bad-volume\n"
        if not 0 <= lvl <= 100:
            return "ERR bad-volume\n"
        _state["volumes"][node] = lvl
        return f"OK volume:{node}:{lvl}\n"
    if cmd == "MUTE" and len(parts) == 2:
        node = parts[1].lower()
        if node not in VALID_NODES:
            return "ERR bad-node\n"
        _state["muted"][node] = True
        return f"OK muted:{node}\n"
    return "ERR bad-command\n"
