"""halide netd->NM bridge (host owns network, Android is client).

Android netd sends single-line requests; host translates to
NetworkManager operations. Single-stack: host wins on conflict, but
this skeleton always OKs well-formed input. No threads, no deps,
<5MB RSS — safe on 4GB tier phones.

Protocol (unix SOCK_STREAM /run/halide/netd.sock):
  REQ: "UP <iface>\\n" | "DOWN <iface>\\n" | "DNS <ip>\\n"
  RESP: "OK up:<iface>\\n" | "OK down:<iface>\\n" | "OK dns:<ip>\\n"
        | "ERR <reason>\\n"
"""
VALID_IFACES = frozenset({"wlan0", "rmnet0"})

_state: dict = {"ifaces": {"wlan0": "down", "rmnet0": "down"}, "dns": ""}

def _valid_ip(ip: str) -> bool:
    quads = ip.split(".")
    if len(quads) != 4:
        return False
    for q in quads:
        if not q.isdigit() or not q:
            return False
        if not 0 <= int(q) <= 255:
            return False
    return True

def handle(line: str) -> str:
    parts = line.strip().split()
    if not parts or not parts[0]:
        return "ERR empty\n"
    cmd = parts[0].upper()
    if cmd in ("UP", "DOWN") and len(parts) == 2:
        iface = parts[1]
        if iface not in VALID_IFACES:
            return "ERR bad-iface\n"
        _state["ifaces"][iface] = "up" if cmd == "UP" else "down"
        verb = "up" if cmd == "UP" else "down"
        return f"OK {verb}:{iface}\n"
    if cmd == "DNS" and len(parts) == 2:
        ip = parts[1]
        if not _valid_ip(ip):
            return "ERR bad-ip\n"
        _state["dns"] = ip
        return f"OK dns:{ip}\n"
    return "ERR bad-command\n"
