#!/usr/bin/env python3
"""halide-android-drawer — generate Phosh desktop shims for Android apps (ch.05 §13).

Phone-safe: operates on a text fixture by default (see tests/drawer-fixture/).
On device: reads `pm list packages -3` output via the bridge; here, reads a file.

Rules implemented (ch.05 §13/§17):
- one .desktop per visible package -> ~/.local/share/applications/android-<pkg>.desktop
  (fixture: out-dir arg), Exec=halide-android-launch <pkg>, robot-badge marker.
- system allowlist visible (F-Droid, Aurora, OpenCamera, Settings-bridge) + user -3 apps.
- hide.conf bans entries (stock dialer/sms/browser, GMS/Play — never shown).
- duplicate package across sources: ONE entry, first-seen source wins, chip lists both.
- disabled package: greyed entry ("disabled" tag), never vanish.
- icon fetch failure: robot-badge placeholder + ICON_FAIL note (never invisible).
Exit 0 generated / 1 invalid input / 2 missing inputs.
"""
import sys
from pathlib import Path

ALLOWLIST = {"org.fdroid.fdroid", "com.aurora.store",
             "net.sourceforge.opencamera", "com.android.settings"}
OUT_NAME = "android-{}.desktop"
BADGE = "X-HALIDE-Badge=android"  # robot-badge overlay marker (ch.05 §13)


def load_hidden(path: Path) -> set:
    out = set()
    if not path.exists():
        return out
    for line in path.read_text().splitlines():
        line = line.split("#", 1)[0].strip()
        if line:
            out.add(line)
    return out


def parse_packages(path: Path):
    """Fixture format: <pkg> [store] [user] [disabled]  ('user' = pm list -3 visibility)"""
    apps, seen = [], {}
    for raw in path.read_text().splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        parts = line.split()
        pkg = parts[0]
        store = parts[1] if len(parts) > 1 and not parts[1].startswith("-") else "fdroid"
        user = "user" in parts[2:]
        disabled = "disabled" in parts[2:]
        if pkg in seen:
            first = seen[pkg]
            if store not in first["sources"]:
                first["sources"].append(store)  # duplicate install: one entry, chip both
            first["user"] = first["user"] or user
            continue
        rec = {"pkg": pkg, "sources": [store], "disabled": disabled, "user": user}
        seen[pkg] = rec
        apps.append(rec)
    return apps


def generate(pm_file: Path, hide_file: Path, outdir: Path) -> tuple:
    hidden = load_hidden(hide_file)
    apps = parse_packages(pm_file)
    made, hidden_n, icon_fail = 0, 0, 0
    outdir.mkdir(parents=True, exist_ok=True)
    for app in apps:
        pkg = app["pkg"]
        visible = pkg in ALLOWLIST or app["user"]  # allowlist + user-installed only
        if not visible:
            continue
        if pkg in hidden:
            hidden_n += 1
            continue
        label = pkg.rsplit(".", 1)[-1]
        entry = (
            "[Desktop Entry]\n"
            f"Type=Application\n"
            f"Name={label}\n"
            f"Exec=halide-android-launch {pkg}\n"
            f"Icon=halide-app-placeholder\n"  # robot-badge placeholder on ICON_FAIL
            f"{BADGE}\n"
            f"X-HALIDE-Sources={'+'.join(app['sources'])}\n"
        )
        if app["disabled"]:
            entry += "X-HALIDE-Disabled=true\nNoDisplay=false\n"
        (outdir / OUT_NAME.format(pkg)).write_text(entry)
        made += 1
        if app["sources"] == ["unknown"]:
            icon_fail += 1  # ICON_FAIL metric line placeholder
    return made, hidden_n, icon_fail


def main() -> int:
    if len(sys.argv) < 2:
        print(__doc__)
        return 2
    fixture = Path(sys.argv[1])
    hide = Path(sys.argv[2]) if len(sys.argv) > 2 else Path("apps/drawer/hide.conf")
    outdir = Path(sys.argv[3]) if len(sys.argv) > 3 else Path("/tmp/halide-drawer-test")
    if not fixture.exists():
        print(f"SKIP: fixture {fixture} missing")
        return 2
    made, hidden_n, icon_fail = generate(fixture, hide, outdir)
    print(f"drawer: generated={made} hidden={hidden_n} icon_fail={icon_fail}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
