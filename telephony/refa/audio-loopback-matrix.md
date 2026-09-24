# telephony/refa/audio-loopback-matrix.md -- voice-call audio loopback test wiring (ch.07 S4, modem-audio-loopback-tests)
# Host owns modem audio (halide-audio-bridge.service bound to halide-android.service;
# bridge down mutes call path fail-closed). Telephony-side wiring; gains/measurements live
# in audio/refa/ (call-gains.conf changes need reason + before/after MOS + mixer diff +
# tester initials; no untracked amixer tweaks on dogfood units). ASCII only. No MOS values
# claimed here -- sheets filled at the bench.

[rig]
reference = acoustic head-and-torso simulator (or documented phone-booth box + calibrated
  speaker/mic at 20cm), quiet room <35 dBA
headsets = wired USB-C analog (model + serial logged); BT HFP car-kit reference (make/model
  per carrier/<id>/perf.md); handset fixture
tools = halide-call-state signal monitor; pw-dump + pw-top; mmcli --voice-create-call to echo number
mos_sheet = PESQ-adjacent subjective 1-5, no fake decimals

[five-scripted-calls-per-sku-gate]
1_quiet_room = TODO (MOS sheet + mixer dump + gains SHA + room dBA)
2_street_75dba = TODO (pink + traffic loop)
3_car_cabin = TODO
4_speakerphone_1m = TODO
5_wired_headset = TODO

[procedures]
sidetone = echo-back call, speak 10s, record sidetone_db in call-gains.conf (audible, not howling);
  sweep mic gain +-6dB, pick lowest holding MOS >=3.5 quiet
echo = far-end swept sine + speech, near-end silent; residual at far-end tap (PipeWire monitor);
  pass: no audible echo after 2s convergence handset/headset, <=4s speakerphone;
  EchoRef = downlink verified in pw-dump
double_talk = both ends 10s x3; intelligibility MOS >=3.0 street, >=3.5 quiet;
  clipping/one-direction gating FAILS the run -> retune AEC tail before gains
archive_per_run = amixer contents + pw-dump + gains SHA + room dBA + headset model + MOS sheet

[sco-vs-handset-matrix]
earpiece_quiet+street_2x5min = MOS >=3.5 / >=3.0, no one-way audio : TODO
speaker_1m-quiet+car_2x5min = echo <=4s, MOS >=3.0 : TODO
wired_reference_1x5min = sidetone present, noise floor <-60 dBFS : TODO
bt_sco_hfp_10min = no drop, reconnect-after-toggle x5 : TODO
a2dp_30min_per_side = 0 underrun flags in dmesg/bridge metrics : TODO
order = host-only call FIRST (no Android), then bridged; diff mixer dumps to isolate bridge
  regressions (S8 one-way-audio rule)

[automation]
script = tests/audio-loopback.sh <sku> <path> (reference clip into mic fixture, record far-end,
  level/delay/echo-residual heuristics, bundle to audio/<sku>/results/<date>/)
ci = fixture-present check on lab runners; VIRT parser-only smoke
regression_gate = any MR touching audio-bridge, call-gains, or PipeWire routing attaches a fresh
  quiet+street pair or states why not
redaction = halide-log-collect --redact before commit (no IMSI/IMEI in audio bundles)
