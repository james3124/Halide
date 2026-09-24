# FORMATS.md — supported audio formats, HALIDE v1 (ch.04 §8 boundary + §30 cert + BT §40)
**Owner: audio bring-up · Phase: 2–3 — codec-noted claims only (BT rows without codec label are rejected)**

## PCM / host path (PipeWire, 48kHz-fixed resampler boundary, ch.04 §8)

| Direction | Rates | Depths | Note |
|---|---|---|---|
| playback (speaker/handset/3.5mm) | 48k (native), 44.1k resampled | 16/24-bit | resampler checked: no alias images above −80dBFS (§30) |
| capture (mic) | 48k | 16/24-bit | ambient dBA footnoted per take (measurements.md method) |
| BT SCO call | 8k/16k mSBC | 16-bit | path per modem-audio-loopback-tests |

## Decoder support (container/AudioFlinger)

| Codec | Decode | v1 status |
|---|---|---|
| AAC (LC) | yes | decodes; BT A2DP AAC optional-per-headset (allowlist `bt/<sku>/a2dp-pin.conf`) |
| FLAC | yes | lossless local playback |
| Opus | yes | network/streaming |
| MP3/eAAC+ | yes | baseline |
| Widevine/DRM audio | non-goal v1 | ch.01 §12 posture |

## Bluetooth codecs (A2DP software path, v1 default per ch.04 §592 doctrine)

| Codec | v1 | Note |
|---|---|---|
| SBC | yes — mandatory | bitpool 53 / 328kbps, MTU 672; HCI-logged codec label on every BT measurement |
| AAC | optional-per-headset | needs HCI negotiation proof + cert row with codec footnoted |
| LDAC / aptX | **OFF** | license + unmeasured path — v1 ships without; promotion needs the §40 allowlist evidence |

Expected: `pw-dump` shows 48kHz-fixed graph; BT `bluetoothctl info` shows SBC negotiated; no LDAC/aptX endpoint advertised.

Fail action: codec flap 44.1↔48k on reconnect = cert bug (ch.04 offload-gate battery row).
