# frame-join miss classifier inputs (ch06 s14/s25 + ch03 s31 reclaim-wait)
# Join key: frame_seq (monotonic per surface).
# CSV: graphics/refa/frame-join.csv columns:
# seq,acquire_us,import_us,commit_us,callback_us,sf_latency_us,delta_ms,missed_bool
# Classifier labels (auto-classified by halide-frame-report):
# MISS-FENCE    acquire-wait ate margin -> route BSP driver/icc (never fix by +margin)
# MISS-IMPORT   modifier-fallback path -> route allowlist gap (modifiers.conf)
# MISS-CALLBACK compositor overload/prio -> route prio-map.txt audit
# MISS-MARGIN   all stages fast, commit past vblank -> only class allowing +0.5ms
# RECLAIM-WAIT  psi some/full stall correlates with miss (dalvik heap vs zram note
#               ch03 s31; dalvik heapgrowthlimit 256m on 4GB) -> route memory/lmkd,
#               not graphics. Inputs: /proc/pressure/memory some_avg10 + frame window.
# Bars: scroll <5% missed; p95 <=20ms at 60Hz; fence-wait p95 <=8ms.
# VIRT nightly = trend only, never gate-worthy.
