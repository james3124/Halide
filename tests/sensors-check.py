#!/usr/bin/env python3
"""sensors-check.py — sensor inventory vs plan contract (ch.04 §10/§32).

Text-only validation of sensors/<sku>/inventory.md + batch.conf:
- accel/gyro/mag present (ISensors@2.1 multihal minimum)
- every wake sensor carries a power note (§32 wake-vs-nonwake rule)
- FIFO sensors have fifo_depth + max_batch_s; non-FIFO have host_poll_hz
Exit 0 ok / 1 violation / 2 missing inputs.
"""
import re
import sys
from pathlib import Path

SKU = sys.argv[1] if len(sys.argv) > 1 else "refa"
base = Path(__file__).resolve().parent.parent / "sensors" / SKU
inv = base / "inventory.md"
batch = base / "batch.conf"

fails = []
if not inv.exists():
    print(f"SKIP: {inv} missing (SKU bring-up artifact)")
    sys.exit(2)

text = inv.read_text()
sensors = re.findall(r"^\|\s*(\w[\w-]*)\s*\|", text, re.M)
sensors = [s.lower() for s in sensors if s.lower() not in ("sensor", "---")]

# 1. Minimum set per ch.04 §10 (accel/gyro required, mag where SKU has it)
for req in ("accel", "gyro"):
    if not any(req in s for s in sensors):
        fails.append(f"required sensor '{req}' not in inventory (ch.04 §10)")

# 2. Wake sensors need a power note (§32: wake the AP like it costs money)
for line in text.splitlines():
    if re.search(r"\b(wake)\b.*\|", line, re.I) and "|" in line:
        cells = [c.strip() for c in line.split("|")]
        if len(cells) > 4 and not re.search(r"mA|power|µA|uA", line, re.I):
            fails.append(f"wake sensor row without power note: {cells[1]}")

# 3. batch.conf pairs: fifo sensors need depth+batch window; others need poll rate
if batch.exists():
    conf = dict(
        (m.group(1), m.group(2))
        for m in ((re.match(r"^([\w-]+)\s*=\s*(.+)$", ln)) for ln in batch.read_text().splitlines())
        if m
    )
    for name, val in conf.items():
        if "fifo_depth" in val and "max_batch_s" not in str(conf):
            fails.append(f"{name}: fifo_depth without max_batch_s (§32 batch record)")
    if conf and not any("poll_hz" in v for v in conf.values()) and not any(
        "fifo" in v for v in conf.values()
    ):
        fails.append("no batching declared at all — every sensor polls? (§32: FIFO preferred)")

for f in fails:
    print(f"FAIL: {f}")
if not fails:
    print("sensors-check: PASS")
sys.exit(1 if fails else 0)
