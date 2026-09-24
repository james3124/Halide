"""halide prop->dbus bridge (host side, single consent source).

Android sysprops in ALLOWLIST sync to host D-Bus; host wins on conflict.
No threads, no deps, <5MB RSS — safe on 4GB tier phones.

Protocol (unix SOCK_STREAM /run/halide/prop.sock):
  REQ: "GET <key>\\n" | "SET <key> <value>\\n"
  RESP: "OK <value>\\n" | "OK\\n" | "ERR <reason>\\n"
"""
ALLOWLIST = frozenset({
    "persist.sys.locale",
    "persist.sys.timezone",
    "sys.boot_completed",
})

_store: dict = {}

def handle(line: str) -> str:
    parts = line.strip().split(" ", 2)
    if not parts or not parts[0]:
        return "ERR empty\n"
    cmd = parts[0].upper()
    if cmd == "GET" and len(parts) == 2:
        key = parts[1]
        if key not in ALLOWLIST:
            return "ERR denied\n"
        return f"OK {_store.get(key, '')}\n"
    if cmd == "SET" and len(parts) == 3:
        key, val = parts[1], parts[2]
        if key not in ALLOWLIST:
            return "ERR denied\n"
        if len(val) > 256:
            return "ERR too-long\n"
        _store[key] = val
        return "OK\n"
    return "ERR bad-command\n"
