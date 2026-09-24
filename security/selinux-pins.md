# selinux-pins.md — SELinux pins (ch.08 §31 per-domain allowlist + neverallow audit expansion)
**Owner: Security · Phase: 1+ — permissive-off rule is absolute on user builds**

## Neverallow list (compile gate; waivers need an ADR, not a shrug)

```
neverallow untrusted_app self:process execmem;
neverallow * * *:binder *;   # binder via allowlisted domains only — no wildcard service grants
neverallow halide_* device:blk_file { write append };   # raw block writes denied host-side
neverallow halide_android persist_file:file { write append };  # efs/persist sealed (ch.08 S10)
neverallow * kernel:process { setcurrent transition };  # no domain auto-transition games
```

## Rules

1. **Permissive OFF on user builds** — `getenforce` → Enforcing both namespaces; a permissive domain on user = release gate FAIL (ch.08 §7 checklist).
2. Every `allow` line carries a justification block (bug + expiry + test) within 5 lines above — lint rejects bare allows (`sepolicy-deltas.txt` sample rows follow this).
3. `audit2allow` output committed raw is banned; wildcard allows rejected by grep in CI.
4. Per-domain allowlist lives in `security/selinux-allowlist.csv` (joined with `sepolicy-deltas.txt`); new domains need Arch + Security review.
5. Debug domain + permissive must not exist on user variants (user-variant absence gate).

Expected: `sesearch --allow` matches the CSV rows only; neverallow compile passes; CI allowlist grep green.

Fail action: any unlabeled allow found at release = block release, open BUG with domain + target class.
