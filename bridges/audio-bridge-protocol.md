# Bridge Protocol: halide-audio-bridge
**Parent: ch.04 §8, ch.05 §9 · Owner: Platform/Audio · Version: v1**

## 1. Parties & transport

Host daemon `halide-audio-daemon` (PipeWire client, user `halide-audio`) ↔ container `audio.primary.halide` HAL proxy over UNIX STREAM `/run/halide/audio-proxy.sock` (`0660 root:halide-audio`, `SO_PEERCRED` allowlist: container `audioserver` only). Framing: length-prefixed protobuf `AudioEnvelope` (`bridges/proto/audio_bridge.proto`, `proto_v=1`).

Host owns the ALSA card exclusively (udev rule + LXC device list denies container direct `/dev/snd` — ch.05 §9). All Android audio arrives as streams to mix, never as device opens.

## 2. Stream model

`OPEN_STREAM {dir (PLAY/CAPTURE), role (Multimedia/Phone/VoiceComm/Alarm), rate, channels, format}` → host replies `StreamHandle {id, negotiated_rate=48000, latency_ms}` or `BUSY/ DENIED`. Roles map to PipeWire nodes: `Multimedia`→`media.role=Multimedia`, `Phone`→`media.role=Phone` (echo-cancel chain per `audio/<sku>/policy.json`), `VoiceComm` (VoIP apps)→`media.role=Communication` with EC, `Alarm`→high-priority duck-others.

`WRITE_PCM {id, seq, frames}` / `READ_PCM {id, seq, frames}` carry raw S16LE/FLOAT32 (negotiated; resample at proxy boundary only — ch.04 §8). `SET_VOLUME {id|role, gain_db}` and `SET_MUTE` mirrored both directions (host slider moves Android `AudioService` volume and vice versa — single truth with last-writer-wins + 200ms debounce to avoid slider fights).

Call preemption: `org.halide.CallState OFFHOOK` → daemon ducks `Multimedia` −20dB, routes modem PCM (`Phone` role) with per-SKU gains (`audio/<sku>/call-gains.conf`); `IDLE` restores with 500ms fade (no clicks — fade verified in 5-call tuning log, ch.04 §8).

## 3. Underrun/overrun discipline

Each stream has a 200ms jitter buffer (tunable per SKU in `policy.json`). Underrun (container late): daemon plays silence + `UNDERRUN` counter; >5/min sustained triggers `AUDIO_STRESS` journal + `halide-power`-visible flag (buffer vs power tradeoff — bigger buffer costs latency, recorded decision per SKU). Overrun (capture late): drop-oldest + counter. Sequence numbers detect loss: gap → `SEQ_GAP` metric + conceal (repeat last frame once, then mute — no garbage burst).

## 4. Formats, rates, effects

Negotiated: 48kHz S16LE default; FLOAT32 for pro-audio apps on request (host converts). No double-EQ (ch.04 §8 single-EQ rule): Android `audio.effect` bundle is pass-through; host-side EQ owned by user settings. Loopback test: 1kHz sine from Android app → host record → THD+N measured, baseline in `audio/<sku>/measurements.md`; any MR touching gains/filters re-runs and attaches the plot.

## 5. Security & limits

Max message 256KB (one PCM chunk ≤64KB nominal; oversize = close + metric). `execve` denied in daemon seccomp (ch.08 §10). `SET_VOLUME` clamp: Phone role max gain capped per SKU (hearing-safety + speaker-protection — cap value from speaker datasheet, in `policy.json` with source comment). Fuzz: `fuzz_audio_parser` over envelope decoder + PCM-header paths.

## 6. Contract test

`bridges/tests/audio_contract.sh`: fake HAL peer opens Multimedia + Phone streams, pushes sine, asserts host mix meters move; call-preemption sequence (OFFHOOK→duck verified via meter delta −20±2dB→IDLE fade); volume mirror both directions; oversize rejection. Sine THD assertion vs baseline ±3dB.

## Verification

- [ ] Contract green; 5-call tuning log + `tinymix` baseline archived per SKU.
- [ ] Duck depth −20±2dB measured; no clicks on restore (waveform attached).
