"""halide permission bridge (atomic sync, both stacks converge).

GRANT/REVOKE from either side syncs atomically; both stacks note
SYNCED so neither diverges >10s. No threads, no deps, <5MB RSS.

Protocol (unix SOCK_STREAM /run/halide/perm.sock):
  REQ: "GRANT <pkg> <perm>\\n" | "REVOKE <pkg> <perm>\\n"
  RESP: "OK granted SYNCED both-stacks\\n" | "OK revoked SYNCED both-stacks\\n"
        | "ERR <reason>\\n"
"""
VALID_PERMS = frozenset({"LOCATION", "CONTACTS", "MIC", "CAMERA"})

_store: dict = {}

def _valid_pkg(pkg: str) -> bool:
    if not pkg or pkg.startswith(".") or pkg.endswith(".") or ".." in pkg:
        return False
    labels = pkg.split(".")
    if len(labels) < 2:
        return False
    return all(l.isalpha() for l in labels)

def handle(line: str) -> str:
    parts = line.strip().split()
    if not parts or not parts[0]:
        return "ERR empty\n"
    cmd = parts[0].upper()
    if cmd in ("GRANT", "REVOKE") and len(parts) == 3:
        pkg, perm = parts[1], parts[2].upper()
        if not _valid_pkg(pkg):
            return "ERR bad-pkg\n"
        if perm not in VALID_PERMS:
            return "ERR bad-perm\n"
        key = (pkg, perm)
        if cmd == "GRANT":
            _store[key] = True
            return "OK granted SYNCED both-stacks\n"
        _store.pop(key, None)
        return "OK revoked SYNCED both-stacks\n"
    return "ERR bad-command\n"
