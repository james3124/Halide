# Modem Audio Loopback Tests
**Parent: 07-telephony-modem-data.md / 04-aosp-base-hals (audio proxy)**

## 1. Scope and ownership
Host owns modem audio. PipeWire is the single mixer; modem PCM routes through host gains in `audio/<sku>/call-gains.conf`. Android AudioFlinger is a client of `halide-audio-bridge` (`/run/halide/audio-proxy`), never a second mixer. This file defines loopback fixtures for sidetone, echo, and double-talk across SCO vs handset paths. systemd-as-PID1: `halide-audio-bridge.service` bound to `halide-android.service`; bridge down mutes call path fail-closed.
Redaction: audio test logs contain no IMSI/IMEI; `halide-log-collect --redact` enforced before commit.

## 2. Fixtures and lab rig
Reference rig: acoustic head-and-torso simulator (or documented phone-booth box + calibrated speaker/mic at 20 cm), quiet room <35 dBA, reference headsets: wired USB-C analog (model + serial logged), BT HFP car-kit reference (e.g. documented make/model per `carrier/<id>/perf.md`), and handset fixture. Tools: `halide-call-state` signal monitor, PipeWire `pw-dump` + `pw-top`, `mmcli -m <m> --voice-create-call` to echo number, PESQ-adjacent subjective MOS sheet (1–5, no fake decimals).
5 scripted calls per SKU gate (ch.07 §4): quiet room, street noise (75 dBA pink + traffic loop), car cabin, speakerphone at 1 m, wired headset.

## 3. Sidetone, echo, double-talk procedures
1. Sidetone: place call to echo-back number, speak 10 s at normal voice, record sidetone level in `call-gains.conf` (`sidetone_db`); must be audible but not howling. Sweep mic gain ±6 dB, pick lowest that holds MOS ≥3.5 in quiet.
2. Echo: far-end plays swept sine + speech while near-end silent; measure residual echo at far-end tap (PipeWire monitor port). Pass: no audible echo after 2 s convergence on handset and headset; speakerphone converges ≤4 s. EchoRef correctly plumbed (`EchoRef` source = downlink, verified in `pw-dump`).
3. Double-talk: both ends speak simultaneously 10 s × 3 runs; score intelligibility both directions (MOS ≥3.0 street, ≥3.5 quiet). Clipping or one-direction gating fails the run — retune AEC tail length before touching gains.
4. Each run archives: mixer dump (`alsamixer`-equivalent `amixer contents` + `pw-dump`), gains file SHA, room dBA, headset model, MOS sheet scan.

## 4. SCO vs handset matrix
| Path | Fixture | Duration | Pass bar |
|---|---|---|---|
| Earpiece handset | quiet + street | 2 × 5 min | MOS ≥3.5 / ≥3.0, no one-way audio |
| Speakerphone | 1 m quiet + car | 2 × 5 min | echo converges ≤4 s, MOS ≥3.0 |
| Wired headset | reference model | 1 × 5 min | sidetone present, no hiss (noise floor <-60 dBFS) |
| BT SCO/HFP | car kit + BT headset | 10-min HFP call | no drop, reconnect-after-toggle ×5 passes |
| A2DP music each side | same headsets | 30 min per side | 0 underrun flags in `dmesg`/bridge metrics |
Test order: host-only call first (no Android), then bridged call; diff mixer dumps to isolate bridge regressions (ch.07 §8 one-way-audio rule).

## 5. Gain file discipline
`audio/<sku>/call-gains.conf` holds earpiece/speaker/mic/EchoRef/sidetone per path. Changes require: reason, before/after MOS, mixer diff, tester initials. No direct `amixer` tweaks on dogfood units without committing the file — untracked gain tweaks are the classic unreproducible-audio bug. HFP routing note: modem-PCM → SCO → car, never through container DSP (ch.07 §12).

## 6. Automation and regression
`tests/audio-loopback.sh <sku> <path>`: plays reference clip into mic fixture, records far-end, computes level/delay/echo-residual heuristics + archives bundle to `audio/<sku>/results/<date>/`. CI runs fixture-present check on lab runners; VIRT runs parser-only smoke. Regression gate: any MR touching audio-bridge, call-gains, or PipeWire routing attaches a fresh quiet+street pair or states why not.

## Verification
- [ ] 5 scripted calls recorded per SKU with MOS sheets + mixer dumps archived.
- [ ] SCO vs handset matrix green: HFP 10 min, A2DP 30 min/side, reconnect ×5.
- [ ] Echo converges ≤2 s handset / ≤4 s speaker; double-talk MOS ≥3.0 street.
- [ ] Host-only vs bridged diff procedure followed for every one-way-audio bug.
- [ ] Log bundles redacted (no IMSI/IMEI); gains file committed with SHA referenced.
