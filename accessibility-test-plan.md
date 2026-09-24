# Accessibility Test Plan
**Parent: 01-vision-requirements-personas.md (NFR Accessibility) / 06-graphics-wayland-phosh-bridge.md**

## 1. Scope and stacks
Phosh a11y stack intact is the v1 contract; Android TalkBack is best-effort and labeled as such. Covers screen-reader (SR) task battery, haptics redundancy, high-contrast/large-text goldens. systemd-as-PID1: `phosh.service` + `halide-android.service` both up for cross-stack tests; single-consent permission prompts must be SR-navigable (permission atomicity includes a11y path — a grant the SR user cannot operate is a bug).
Environments: REF-A + REF-B, Phosh light/dark, font scale 1.0/1.5/2.0, high-contrast on/off.

## 2. SR-scripted task battery
Runner: Orca (host) + TalkBack (container, best-effort) with scripted key/swipe sequences in `tests/a11y-battery.sh`. Each task timed + pass/fail, 2 testers minimum (1 SR-daily user per release).
| ID | Task | Stack | Pass bar |
|---|---|---|---|
| SR-01 | Unlock with PIN via SR | Phosh lock | 3/3 unaided, ≤60 s |
| SR-02 | Place call via GNOME Calls | host | dial + hangup announced, ≤90 s |
| SR-03 | Read + reply SMS in Chats | host | message text spoken verbatim |
| SR-04 | Open Android app from drawer | bridge | badge + label announced, launch ≤10 s |
| SR-05 | Revoke location in one place | both | revocation confirmed both stacks ≤10 s |
| SR-06 | Join Wi-Fi + read signal | Settings/NM | SSID + connected state announced |
| SR-07 | Install F-Droid app update | container | progress + done announced |
| SR-08 | Emergency dialer reach | host | reachable ≤3 gestures from lock |
Record Orca version, TalkBack version, `phosh` version per run; failures attach `journalctl` + `logcat -b all` (redacted) + screen recording.

## 3. Haptics redundancy checks
Every critical alert has ≥2 channels (visual + haptic and/or audio): incoming call, SMS/OTP arrival, low battery (≤15%), OTA reboot prompt, permission prompt. Procedure: trigger each with vibration motor on/off; with haptics off the visual banner must persist until acknowledged; with display off the vibration pattern must differ call-vs-SMS (call = repeating, SMS = double-pulse). Measure motor latency tap→buzz <50 ms (`evtest` + accelerometer jig where available, else high-speed camera). Document missing-motor SKUs as known gaps, never silent.

## 4. High-contrast and large-text goldens
Golden PNGs per combination (light/dark × 1.0/1.5/2.0 × HC on/off) for: lock screen, Phosh home + drawer, Settings → Privacy, Calls dialer, Chats thread, one Android app window via composer. CI screenshot diff ≤2% pixels (ch.09 §11); HC runs additionally assert contrast ratio ≥7:1 on body text via `halide-contrast-check` (sampling 9 regions). Large-text 2.0× must not clip primary actions (Call, Send, Approve, Wipe-confirm) — clipped action fails the run. `grim` (host) + `screencap` (container) pairs archived to prove single color pipeline under HC LUT.

## 5. Input and focus discipline
Touch→photon <100 ms budget still applies with SR running (regression allowance +20 ms, recorded). Focus order audited: lock → home → drawer → dialogs trap focus (no focus escape to background window — overlay-attack test doubles as a11y focus test). Keyboard-only full pass quarterly (USB/BT keyboard, no touch): every SR-0x task completable.

## 6. Defect Laurel and release gate
A11y bugs carry `a11y` label + severity bump (blocker = cannot call/message/unlock with SR). Release gate: SR-01..SR-08 green on REF-A, goldens within tolerance, haptics matrix green. Known TalkBack gaps listed in release notes with bug IDs, never marketed as supported.

## Verification
- [ ] SR battery SR-01..SR-08 green with 1 SR-daily tester; logs + versions archived.
- [ ] Haptics redundancy matrix green; call vs SMS patterns distinguishable display-off.
- [ ] HC/large-text goldens within ≤2% diff; contrast ≥7:1; no clipped primary actions.
- [ ] Keyboard-only pass complete; focus-trap holds on permission + lock dialogs.
- [ ] TalkBack gaps honestly listed; Phosh SR path has zero blocking defects.
