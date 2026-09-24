# Audio measurements method (text-only)
1. Call path: CMTS loopback, tinymix-baseline applied, record uplink/downlink.
2. Media path: 1 kHz sine via speaker, mic at 10 cm, log THD+N.
3. Method: 3 runs each, note ambient dBA and battery level.
4. Tooling: tinymix + arecord/aplay only; no proprietary DSP tools.
5. Expected: voice intelligible no clipping; media THD+N < -40 dBFS stub gate.
6. Fail action: adjust call-gains.conf, re-record, attach logs/.
7. Ref: audio/refa/call-gains.conf, audio/refa/policy.json; wavs outside repo.
8. Gate: pass required before carrier sample sign-off.
9. No binaries here; text plan only.
10. Routes (ch.07 §23): HANDSET (earpiece+mic), SPEAKER (loudspeaker+top-mic AEC ref),
    BT-SCO (HFP via host BlueZ — hsphfpd AG, SCO params logged), WIRED-3.5MM.
    Break-before-make transitions, 50–150ms crossfade; one active route per call.
