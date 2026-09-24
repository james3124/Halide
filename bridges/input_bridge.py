"""halide touch/input bridge (host side, single consent source).

Android input stack sends single-line requests; host injects via
uinput/libei. No threads, no deps, <5MB RSS — safe on 4GB tier phones.

Protocol (unix SOCK_STREAM /run/halide/input.sock):
  REQ: "TAP <x> <y>\\n" | "SWIPE <x1> <y1> <x2> <y2>\\n" | "KEY <code>\\n"
  RESP: "OK injected:<ACTION>\\n" | "ERR <reason>\\n"
"""
MAX_COORD = 4096

def _coord(tok: str):
    try:
        v = int(tok)
    except ValueError:
        return None
    if 0 <= v <= MAX_COORD:
        return v
    return None

def handle(line: str) -> str:
    parts = line.strip().split()
    if not parts or not parts[0]:
        return "ERR empty\n"
    cmd = parts[0].upper()
    if cmd == "TAP" and len(parts) == 3:
        if _coord(parts[1]) is None or _coord(parts[2]) is None:
            return "ERR bad-coords\n"
        return "OK injected:TAP\n"
    if cmd == "SWIPE" and len(parts) == 5:
        if any(_coord(t) is None for t in parts[1:5]):
            return "ERR bad-coords\n"
        return "OK injected:SWIPE\n"
    if cmd == "KEY" and len(parts) == 2:
        try:
            code = int(parts[1])
        except ValueError:
            return "ERR bad-key\n"
        if not 1 <= code <= 255:
            return "ERR bad-key\n"
        return "OK injected:KEY\n"
    return "ERR bad-command\n"
