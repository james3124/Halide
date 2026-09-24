# Sepolicy Deltas — Device Policy on Top of AOSP (with expiry discipline)
**Parent: ch.04 §14, ch.08 §4 · Location: `device/halide/sepolicy/` · Rule: every allow has BUG + EXPIRY + test**

## 1. File layout

```
device/halide/sepolicy/
  halide.te            # container + bridge domains
  halide_container.te  # u:r:container internals (minimal additions only)
  halide_rild.te       # rild QRTR + bridge socket access
  halide_camera.te     # camera provider dmabuf + persist-ro calibration read
  halide_audio.te      # audio proxy socket client
  halide_composer.te   # (host-side reference; real enforcement is AppArmor — keep in sync)
  file_contexts.halide # /run/halide/*, /dev/binderfs, vendor persist-ro paths
  neverallow.halide    # invariants CI enforces (below)
  BASELINE.avc         # logs/<sku>-selinux-baseline.txt committed copy
```

## 2. neverallow invariants (CI `checksepolicy -M -c 30` fails the build on violation)

```
# Container must never write calibration / modem NV
neverallow container persist_block:blk_file write;
neverallow container efs_block:blk_file { write append };
# Container must never transition to host bridge domains
neverallow container halide_bridge_exec:file { entrypoint execute };
# rild talks QRTR + bridge socket only — no raw diag widening as a shortcut
neverallow halide_rild diag_device:chr_file { read write };
# Camera reads calibration read-only; no persist write to "fix" tuning
neverallow halide_camera persist_file:file write;
# No unconstrained binder across the boundary (use the bridge macros)
neverallow { container halide_rild halide_camera halide_audio } self:binder { call transfer };
```

Each neverallow has a comment with the incident-or-reason it guards (rules without reasons get deleted in review — dead rules hide real ones).

## 3. Reviewed allow patterns (copy these shapes, not blanket allows)

```te
# BUG:HAL-214 EXPIRY:2026-12-01 TEST:ril_contract.sh — rild needs QRTR control socket
allow halide_rild qrtr_socket:sock_file { read write open };
allow halide_rild self:qrtr_socket { create read write bind };

# BUG:HAL-231 EXPIRY:upstream-lore-v5 TEST:camera-burst.sh — provider imports dmabuf from CAMSS
allow halide_camera halide_camera:fd use;
allow halide_camera dmabuf_heap:chr_file { read write map };

# BUG:HAL-240 EXPIRY:2026-10-15 TEST:audio_contract.sh — audioserver client to host proxy socket
allow halide_audio halide_bridge_sock:sock_file { read write open };
```

Expiry bot: weekly CI job lists rules expiring ≤30 days → auto-files `RENEW-or-REMOVE` task to owner; expired rule without renewal MR fails the release build (not silently kept).

## 4. Audit-to-allow workflow (exact, no cowboy allows)

```bash
# 1. reproduce scenario on userdebug, pull audits
adb shell 'cat /proc/kmsg' | grep avc > /tmp/avc-raw.txt
# 2. propose (never --allow-all)
audit2allow -p out/target/product/<sku>/root/sepolicy < /tmp/avc-raw.txt > /tmp/proposed.te
# 3. triage each hunk: expected-and-scoped (write with BUG/EXPIRY/TEST) |
#    expected-but-too-broad (narrow to macro: binder_call(src,dst), unix_socket_connect) |
#    unexpected (file platform bug, no allow)
# 4. regenerate baseline + diff
adb shell dmesg | grep avc | audit2allow -p ... # confirm zero new denials post-fix
diff logs/<sku>-selinux-baseline.txt <(new-baseline) || explain-every-hunk
```

Macro discipline: `binder_call(A,B)` over `allow A B:binder call`; `unix_socket_connect(A,SOCK)` over raw `sock_file` write. Quarterly macro-coverage check (raw allows trending down).

## 5. Host SELinux note (where Debian host enables it) + AppArmor sync table

Where host runs SELinux (enterprise SKUs): container processes labeled `system_u:system_r:container_t` and the AppArmor profiles (ch.08 §10) mirror the same socket allowlists — `scripts/mac-sync-check.sh` diffs `SOCKETS.md` vs `.te` vs AppArmor rules; any socket in one but missing in another fails CI (three-way sync, ch.09 §11 MR gate).

## Verification

- [ ] `neverallow` set compiles + enforced in CI; expiry bot green (0 overdue).
- [ ] Baseline diff empty-or-justified on release candidate.
