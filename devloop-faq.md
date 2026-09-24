# Dev-Loop FAQ — Fastest Correct Iteration per Subsystem (read before asking in chat)
**Parent: all build chapters · Purpose: kill the "how do I test X quickly" round-trips · Verified quarterly (stale fast-paths are lies)**

## 1. Kernel-only change (driver/DT, no userspace)

```bash
make ARCH=arm64 O=out/$SKU -j$(nproc) Image.gz dtbs modules   # ~4 min ccache-hot
fastboot boot out/$SKU/boot.img   # RAM-only (never flash for a test — ch.03 §18)
# probe per subsystem: modetest / evtest / qrtr-lookup / tinymix (see ch.03 §11-17)
```

No container rebuild, no Debian rebuild (if your kernel change needs userspace rebuilds, say so in the MR — silent coupling is the enemy).

## 2. HAL-only change (no kernel, no container image)

```bash
m -j$(nproc) <hal-target>   # e.g. android.hardware.audio@7.1-impl-halide
adb push $OUT/vendor/lib64/<hal>.so /vendor/lib64/   # userdebug dev only
adb shell pkill audioserver   # or relevant HAL host; binder death-recipient restarts it
# verify: dumpsys <service> + relevant contract test (bridges/tests/)
```

Release-path check still required (erofs image assemble + boot — push-to-device proves logic, image proves shippability; both green to merge).

## 3. Bridge-only change (host daemon, no flash at all)

```bash
meson compile -C build halide-<name>-bridge && sudo meson install -C build --tags runtime
sudo systemctl restart halide-<name>-bridge.service
bridges/tests/<name>_contract.sh   # gate (ch.05 §9 — no contract green, no merge)
```

Fuzz 10-min smoke locally before pushing (`halide-fuzz-bridges --only <name> --time 600` — CI runs it anyway; local-first saves everyone's queue).

## 4. Full-image validation (before any MR claiming "works on device")

```bash
scripts/build-all.sh $SKU userdebug && fastboot flashall --skip-wipe(factory lane ch.09 §10)
# then, in order: boot-timing.sh → permission-sync.sh ×5 → relevant subsystem loop → dump-diff.sh vs golden
```

"Works" without the full-image pass = "works on my dirty device" (said kindly in review with a link here).

## 5. When stuck >2h (escalation with logs, not vibes)

Bring: `halide-log-collect --redact` bundle + exact commands run + Expected-vs-got (one paragraph) + what you already tried (3 bullets). Post in office-hours thread (ch.11 §7 Friday slot) — drive-by DMs get a kind redirect (answers in public compound; DMs don't).

## Verification

- [ ] Quarterly: a non-maintainer follows §1–§4 cold and reports friction as doc bugs (P4 story infrastructure, ch.01 §11).
