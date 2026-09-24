# Developer SDK Guide
**Parent: 01-vision-requirements-personas.md (P2 Linux hacker) / 05-debian-systemd-dual-init.md**

## 1. Audience and promises
P2 wants `apt install`, systemd units, Wayland debugging, and out-of-tree modules without asking maintainers. SDK delivers: kernel headers package, one worked module example, bridge client SDK, and sample apps for both stacks. systemd-is-PID1 everywhere: samples ship `.service` units, never sysv scripts. Single-stack networking and permission atomicity are enforced in samples — sample code that double-NATs or silently inherits permissions is rejected in review.
Prereqs: REF-A/B device or QEMU+VIRT, `halide-v` release, builder digest pinned per ch.09.

## 2. Headers package
`linux-headers-halide-<sku>_<ver>_arm64.deb` built alongside kernel (`scripts/build-all.sh` stage 1 artifact, SHA in `logs/build-<sku>-<ts>.json`). Install: `sudo apt install ./linux-headers-*.deb` then `make -C /usr/src/linux-headers-$(uname -r) M=$PWD modules`. Kbuild path committed; DKMS-equivalent flow: `halide-dkms add/show/build` wraps signing for eng (`CONFIG_MODULE_SIG_FORCE` still enforced on release — unsigned modules load on eng only, documented). Verify: `modinfo hello-halide` shows `vermagic` + `sig_id` fields; `dmesg` shows load on eng, refusal on user.

## 3. Module example build
Repo `sdk/hello-halide/`: `hello.c` (param `who`, printk on load/unload), `Makefile` (2 lines + KDIR), `halide-hello.service` (oneshot at boot on eng for demo, disabled by default). Build lab:
```bash
cd sdk/hello-halide && make && sudo insmod hello-halide.ko who="p2"
journalctl -k --grep hello-halide ; sudo rmmod hello-halide
```
Expected: `hello halide p2` in `journalctl -k`, exit 0, no taint beyond `OE` on eng. Troubleshooting table: `Exec format error` → headers mismatch (`uname -r` vs deb); `Required key not available` → release enforcement working, use eng; `No such device` → DT compat missing, check `hw/<sku>/`.

## 4. Bridge client SDK
C + Rust clients for `/run/halide/*` sockets (paths/owners in `bridges/SOCKETS.md`): `libhalide-prop` (locale/timezone/battery poll + allowlisted setprop), `libhalide-net` (query NM truth, request routes — netd-shim semantics, rejections with `PERMISSION_DENIED` + host log), `libhalide-notify` (post to Phosh daemon). Rules: `0660 root:halide-bridges` ACLs respected; `execve` from parsers forbidden (seccomp); every parser ships libFuzzer harness (`halide-fuzz-bridges` 10-min smoke per MR). Sample `bridge-ping`: reads `sys.boot_completed` via prop-bridge and prints D-Bus `org.halide.Android` state; failure prints socket + AppArmor hint (`aa-status`), never suggests `chmod 777`.

## 5. Sample apps for both stacks
Host (Phosh/GTK): `sdk/sample-host/` — Wayland window + notification + permission-store request; `wayland-info` + `sysprof` traces referenced. Android: `sdk/sample-android/` — single-activity APK reading bridged telephony/signal (mirror lag ≤2 s demo) + `SMS_RETRIEVER`-compatible OTP receive via allowlisted broadcast. Drawer integration: `halide-android-drawer` picks up `android.<package>` with `.desktop` shim + robot badge; long-press opens bridged permission page proving atomicity (revoke in sample revokes both stacks ≤10 s via `tests/permission-sync.sh`).

## 6. Debug, symbols, and redaction
Eng images carry symbols + `halide-debug` bundle; release strips. `halide-research` variant (symbols + KASAN userdebug) available for vuln hunters. Support script `halide-log-collect --redact` strips IMSI/IMEI/ICCID before any paste to issues. `UART + ftrace` path (ch.03 §17) reproduced in `sdk/BOOT-TRACE.md` so week-1 bring-up needs no maintainer ping.

## Verification
- [ ] Headers deb installs from release artifacts; `hello-halide` builds, loads on eng, refuses on user with documented error.
- [ ] `bridge-ping` sample reads prop-bridge over correct socket/ACL with fuzz harness present.
- [ ] Host + Android samples install (apt + F-Droid path), appear in drawer, permission revoke hits both stacks ≤10 s.
- [ ] No sample uses double-NAT, direct modem QMI, or DRM master; CI grep for banned calls green.
- [ ] Log bundles from samples are redacted; symbols only on eng/research images.
