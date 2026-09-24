# halide-composer Internals — Threads, Fences & Layer Mapping
**Parent: ch.06 §§6–9 · Owner: Graphics · Language: C++17, no toolkit dep**

## 1. Process anatomy (why 4 threads, what each owns)

`binder-listener`: blocks on SurfaceFlinger-proxy binder (one thread, `POLLPRI`); parses layer list + buffer FDs + acquire fences; validates (modifier allowlist ch.06 §6, size caps per SKU `graphics/<sku>/limits.conf`: max 2× panel area per layer — oversize layer = close + `LAYER_OVERSIZE` metric, never OOM the compositor); pushes validated frames to present queue (depth 3, drop-oldest with `PRESENT_QUEUE_DROP` counter — backpressure goes here, not into binder).

`wayland-present`: owns `wl_display` roundtrip + `zwp_linux_dmabuf_v1` import + `xdg_toplevel` objects; driven by `frame_callback` (no present without callback — no busy-loop present, power rule); closes release fences back to producer on callback; updates stall watchdog timestamps.

`input-forward`: owns `/run/halide/input.sock` writes (ch.06 §7 + input protocol doc); hit-tests against current surface geometries (read-only snapshot from present thread — lock-free RCU snapshot, never a mutex held across `wl_display_dispatch`).

`watchdog`: 500ms tick; checks present-thread heartbeat (no present 2s while visible → fence-timeline dump + `dumpsys SurfaceFlinger` capture + `COMPOSER_STALL` metric + debug-overlay marker); checks FD count growth (`/proc/self/fd` sampled — leak slope >2/min pages graphics owner); checks queue-drop rate (>1% sustained → auto quality note: suggest client throttle hint via `onPause`-adjacent `THROTTLE_HINT`).

## 2. dmabuf import path (exact call order + error branches)

Receive (`AHardwareBuffer` desc + FD + acquire `sync_file`) → modifier check vs `modifiers.conf` → `zwp_linux_dmabuf_v1.create_params` → `add(fd, plane, offset, stride, modifier_hi/lo)` per plane (validate plane count vs format: NV12=2, RGBA=1 — mismatch = reject + log) → `create_immed` → `wl_surface.attach(buf, x, y)` → `wl_surface.damage_buffer(dirty rects)` → `wl_surface.commit` → arm `sync_file` wait (500ms timeout → §3 stall path) → on `frame_callback`: destroy old buffer, send release fence, update latency CSV (event SEQ→present SEQ join, ch.06 §7).

Format table v1 (others rejected with structured error): `ABGR8888`, `XBGR8888`, `RGB565` (legacy dialogs), `NV12`/`YUV420` (video/camera preview), all linear + SKU AFBC modifiers from allowlist. 10-bit (`P010`) Phase-4 (reserve enum, reject with `FORMAT_FUTURE` + metric so demand is measurable).

## 3. Stall & recovery ladder (never silent black)

Level 1 (single fence timeout): re-present previous good frame + overlay marker (debug builds) + counter. Level 2 (3 consecutive): capture `dumpsys SurfaceFlinger --latency`, fence `sync_file` info (`/sys/kernel/debug/sync/sw_sync` where present), `dmesg` DRM slice → `halide-composer-bugreport-<ts>.tar.gz` to `/var/crash/` (redacted: no pixel data — buffers are handles, dump metadata only). Level 3 (no present 10s while visible): emit `COMPOSER_DEAD` on D-Bus → systemd shows "Android display restarting" card → `halide-display-restart` (restarts virtual display service only, ch.06 §9 — not full container) → full-container restart only if display-restart fails twice (escalation logged). Any Level-3 in dogfood = P1 bug with bugreport attached (ch.10 §10 taxonomy).

## 4. Surface lifecycle & Z-order

Android `Task` visible → create `xdg_toplevel` (app_id `android.<pkg>`, title task label); Task invisible >500ms → `onPause` hint (ch.06 §3 power rule) but keep surface 5s (fast task-switch without re-alloc); Task destroyed → destroy surface + release all its buffers (FD-leak test in CI asserts per-task FD delta returns to 0). Z-order: Android tasks stack below host lockscreen/dialogs, above host wallpaper (fixed policy v1 — no Android-over-lockscreen, security rule reviewed in ch.08 threat model: lockscreen bypass via overlay is a listed P0 class).

Multi-window v1 (ch.06 §4): single maximized Android window; geometry changes (keyboard open, rotation) → `xdg_toplevel.configure` + Android `onResize` with 300ms debounce (resize storms coalesced — each configure logged in debug `--trace-resize`).

## 5. Splash & fallback paths

Boot splash: composer starts before Phosh with static logo + stage text (kernel→systemd→android→ready, ch.03 §7 timeouts) via direct DRM dumb-buffer (no Wayland needed — 200 lines, no GPU). GPU-firmware-missing fallback: llvmpipe note in splash ("software rendering — check firmware", never a hang). Suspend: panel-off → visibility-false → pause hints (ch.06 §8); resume → re-import (stale-handle path tested by 50-cycle script with composer running — ch.03 §17 extended).

## Verification

- [ ] FD-growth CI test (task open/close ×50, delta 0); stall ladder demonstrated with injected fence fault.
- [ ] Resize/keyboard/rotation sequences traced clean; lockscreen always above Android surfaces (overlay-attack test).
