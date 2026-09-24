# Bridge Protocol: halide-input (touch/keyboard/stylus)
**Parent: ch.06 §7 · Owner: Graphics/Platform · Version: v1 · Transport: `/run/halide/input.sock` STREAM, binary**

## 1. Frame format (little-endian, fixed 24-byte header + payload)

`MAGIC u16 (0x4849) | VER u8 (1) | TYPE u8 | SEQ u32 | TIME_US u64 | LEN u16` then payload. Unknown TYPE → `UNKNOWN_FRAME` counter + drop (never crash the reader — fuzz rule). SEQ gaps → `SEQ_GAP` metric (transport loss is P1 — local socket shouldn't lose).

## 2. Event types

`TOUCH_DOWN/UP/MOVE {slot u8, x/y u16 (panel px, post-matrix), pressure u16, major_mm u8, tool u8 (FINGER/PALM/STYLUS)}`, `KEY {linux_code u16, value u8 (down/repeat/up)}`, `SWITCH {lid/state}` (lid only v1), `SYN {frame_end}` batching marker (composer batches one vsync worth of moves per SYN — no per-move syscall storm). Coordinates are post-`input-matrix.conf` transform (ch.06 §7) — raw panel coords never cross the socket (calibration stays host-side, single place to fix).

Palm: host marks `TOOL_PALM` (width>18mm heuristic, ch.06 §7); container drops PALM unless 2+ active contacts (edge-swipe false-reject test: 100 swipes, <3 dropped). Stylus: pressure forwarded 0–4095 scaled; tilt dropped v1 (protocol reserves fields, reader ignores with `TILT_DROPPED` debug counter — forward-compat without fake data).

## 3. Keycode mapping

Table `input/android-keymap.csv` (Linux→Android: `KEY_HOMEPAGE→HOME`, `KEY_BACK→BACK`, volume keys, `KEY_POWER` special-cased §4). Unmapped code → forward as `KEYCODE_UNKNOWN` + once-per-boot log (not spam). Modifier state tracked host-side; container receives composed `META_*` flags per event (no desync from lost key-up — resync packet every 5s with full modifier state).

## 4. Power key & emergency (special path, reviewed twice)

Power-key long-press: host intercepts (never forwarded as plain key — pocket-press must not Faberge the radio). Short-press → panel on/off both stacks. Long-press → host power menu (Restart/Recovery/Off/Emergency call) with Android `GLOBAL_ACTION` mirrored for app state save. Emergency-call shortcut from menu dials via host dialer directly (ch.07 §4) — tested per region build, same UNTESTED-bold rule.

## 5. Injector (container side) & latency accounting

`halide-input` device in `InputReader` (id `HALIDE_VIRTUAL`, not a kernel node — `getevent` won't show it, `dumpsys input` will). Each event carries host `TIME_US` (CLOCK_MONOTONIC both sides, disciplined by shared boot clock — offset measured at connect, `CLOCK_SKEW_US` metric, re-sync if >2ms). Touch→present latency CSV (ch.06 §7) joins on SEQ (event SEQ → surface present SEQ — the measurement is end-to-end by construction).

## 6. Limits, fuzz, contract test

Max frame 1KB; >1000 events/s sustained → `EVENT_STORM` + drop MOVEs coalescing to latest position (calls/keys never coalesced). Fuzz `fuzz_input_parser` (bit-flip + length-lie corpora). Contract `tests/input_contract.sh`: scripted tap/swipe/key sequences vs fake injector asserting coords post-matrix, palm drop, modifier resync, power-key interception, storm coalescing.

## Verification

- [ ] 200-tap latency CSV archived per SKU; storm test shows coalesced MOVEs, intact keys.
- [ ] Power-menu + emergency path demonstrated on hardware per region build status.
