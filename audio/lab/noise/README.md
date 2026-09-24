# audio/lab/noise — chamber recordings (acoustic-lab-spec §3 naming + hashes)
**Owner: audio bring-up · Phase: 2–3**

## Naming (16-bit WAV, 60s loop, pink-shaped)

```
noise_<scene>_<level-dB>_<yyyymmdd>.wav
scenes: street | car | home
example: noise_car_70dB_20260601.wav
```

## Calibration

- Levels calibrated **at the DUT mic position**, lid open for setup then closed for test.
- Speaker position fixed 1 m from cradle, marked on floor; hashes pinned here per file.

## Hashes (pinned — a retake replaces the row, never edits silently)

| file | sha256 | cal date |
|---|---|---|
| (no recordings in tree yet — wavs live outside repo) | — | — |

Expected: every take folder references a pinned hash row; unpinned noise files invalidate the tune.

Fail action: missing cal annotation = take invalid, re-record.
