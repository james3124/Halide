# jank dashboard metric definitions (ch06 s12/s14/s21 + low-spec 4GB gate)
# Source counters -> dashboard gauges. All week-over-week trends; regressions page owner.
# MISSED_VBLANK: counter ++ when commit lands past vblank (never block into next
#   vblank holding a fence). Per-minute histogram; regression >2% WoW pages graphics.
#   Gate: scroll <5% missed vsync (200-frame frame_timeline; F-Droid fling workload).
# fence_stalls: sync_file acquire poll 500ms timeout count (HALIDE-FENCE-STALL marker).
#   p95 fence-wait <=8ms; higher = driver/icc, not composer.
# fd_delta: total/dmabuf/syncfile delta after task open/close x50 (must return to 0;
#   dmabuf/syncfile exactly 0, total +-2 shm jitter). Soak slope WARN >4 FD/h, FAIL
#   dmabuf+syncfile slope >0 over 1h. See fd-thresholds.conf.
# touch_p95: touch->frame_callback p95 <100ms over 200 taps (stylus-180 + finger-20
#   appendix <120ms). Method ch06 s30; script graphics/touch-stats.py stats_v2 linear.
# onpause_p95: DISPLAY_OFF -> ONPAUSE_SENT <=500ms (frame-join markers).
# 4GB tier: all gates run on REF 4GB unit, not 8GB lab queen (low-spec-tier s6).
# Release notes carry all five numbers; missing renders NOT-MEASURED (never blank).
# Archiver: halide-frame-report + halide-touch-report + halide-fd-report outputs.
