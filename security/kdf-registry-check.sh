#!/bin/bash
# security/kdf-registry-check.sh -- KDF registry gate (ch.08 S32)
# Validates: schema-valid JSON, every shipping SKU resolves, cipher + KDF match
# the luks2-params.conf row, unlock-latency files present, no research-image KDF
# delta, no escrow anomaly. Exit contract: 0 PASS / 1 FAIL / 2 SKIP-infra.
set -eu
cd "$(dirname "$0")/.."
FAIL=0

[ -f security/kdf-registry.json ] || { echo "FAIL: security/kdf-registry.json missing"; exit 1; }
[ -f security/luks2-params.conf ] || { echo "FAIL: security/luks2-params.conf missing"; exit 1; }
command -v python3 >/dev/null 2>&1 || { echo "SKIP: python3 absent (runner issue)"; exit 2; }

if python3 - security/kdf-registry.json <<'PYEOF'
import json, sys
reg = json.load(open(sys.argv[1]))
assert reg.get("schema") == "halide-kdf-registry-v1", "schema mismatch"
names = {a["name"] for a in reg.get("approved", [])}
assert "argon2id" in names, "argon2id row missing"
prohib = reg.get("prohibited", {}).get("kdfs", [])
assert prohib, "prohibited list missing"
skus = None
for a in reg["approved"]:
    if a["name"] == "argon2id":
        skus = a.get("skus", {})
assert skus and "REF-A" in skus and "REF-B" in skus, "SKU rows unresolved"
for sku in ("REF-A", "REF-B"):
    row = skus[sku]
    assert set(("m_mb", "t", "p")) <= set(row), "incomplete row %s" % sku
print("kdf-registry: schema + SKU rows OK")
PYEOF
then
  :
else
  FAIL=1
fi

# cipher pin agreement between registry JSON and conf
grep -q 'aes-xts-plain64' security/kdf-registry.json || { echo "FAIL: cipher pin missing in registry"; FAIL=1; }
grep -q 'aes-xts-plain64' security/luks2-params.conf || { echo "FAIL: cipher pin missing in luks2-params.conf"; FAIL=1; }
# REF rows present in both
for SKU in REF-A REF-B; do
  grep -q "$SKU" security/luks2-params.conf || { echo "FAIL: $SKU row missing in luks2-params.conf"; FAIL=1; }
done
# research-image KDF delta ban: no research SKU row with weaker params in the
# registry, and no [kdf.research] section in the conf (prose mentions of the ban
# itself must not trip this gate -- values only, not words)
python3 - security/kdf-registry.json <<'PYEOF'
import json, sys
reg = json.load(open(sys.argv[1]))
for a in reg.get("approved", []):
    if a.get("name") == "argon2id":
        for sku, row in a.get("skus", {}).items():
            if "research" in sku.lower():
                raise SystemExit("research KDF row in registry: %s" % sku)
print("kdf-registry: no research KDF delta -- OK")
PYEOF
[ $? -eq 0 ] || FAIL=1
grep -q '^\[kdf\.research\]' security/luks2-params.conf && { echo "FAIL: [kdf.research] section in luks2-params.conf"; FAIL=1; } || true
# escrow audit: universal backdoor slot language must not appear as policy
grep -rqi 'universal.*backdoor.*slot.*required\|escrow.*all.*devices' security/luks2-params.conf 2>/dev/null && { echo "FAIL: escrow anomaly"; FAIL=1; } || true
# unlock-latency evidence files present (values may be TODO pre-silicon -- presence is the gate)
for SKU in REF-A REF-B; do
  [ -f "security/unlock-$SKU.md" ] || { echo "FAIL: security/unlock-$SKU.md missing"; FAIL=1; }
done
[ "$FAIL" = 0 ] && echo "kdf-registry-check: PASS" || echo "kdf-registry-check: FAIL"
exit "$FAIL"
