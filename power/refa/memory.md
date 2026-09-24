# memory.md - REF-A memory management tuning (ch.03 S34)
# Owner: Power/Android. Single truth: HOST owns memory pressure policy;
# Android lmkd runs inside the container but kills only container processes.
# Host systemd-oomd NEVER kills container init - the container is one cgroup
# subtree with its own pressure handling; cross-kill is a P0 bug.
# WHY zram-only v1 (S34): no disk swap (eMMC/UFS wear + LUKS2 dm-crypt
# write-amp - wear math committed below); no zswap (zswap+zram
# double-compression wastes CPU for <3% ratio win measured on REF-A).
# Memory and scheduler share this page's logic (pressure moves frequency,
# frequency moves reclaim - one page prevents split-brain tuning; OPP table
# lives in sched-cpufreq.md S33).

## zram config (host /etc/systemd/zram-generator.conf + container-local zram)
[zram0]
zram-size = min(ram * 0.5, 2048)
# WHY cap 2048MB (S34): 4GB SKU -> 2048MB, 6GB -> 2048MB cap. >2GB zram on a
# 4GB device starves page-cache (measured thrash at 2.5GB).
compression-algorithm = lzo-rle
# WHY lzo-rle not zstd (S34): zstd +12% ratio but 2.1x CPU on little cluster
# during batch-kill storms (zramctl --stats + perf evidence on file).
swap-priority = 100

## Container dalvik heap sizing (device/halide/<sku>/device.mk)
# 4GB: dalvik.vm.heapgrowthlimit=256m | 6GB+: 384m; heapmaxfree=8m both.
# WHY matched to zram (S34): heap too large + small zram = direct-reclaim
# stalls visible as scroll jank (reclaim-wait classifier feeds ch.06 S14
# triage ladder; frame-join fence-wait vs reclaim-wait disambiguation).

## lmkd params - per-RAM-variant tables (DRAM-size fork ch.02 S19 companion:
## side-by-side, never "adjust for RAM" prose)

| Param | 4GB variant | 6GB variant | Why |
|---|---|---|---|
| minfree_levels (pages) | 18432,23040,27648,32256,55296,80640 | 18432,23040,27648,36864,64448,96000 | larger cached-kill headroom where RAM allows |
| kill_heaviest_task | true | true | container kills by adj-weighted size |
| kill_timeout_ms | 100 | 100 | foreground stall bound |
| ro.lmk.psi_complete_stall_ms | 150 | 150 | PSI-mode kill trigger |
| ro.lmk.psi_partial_stall_ms | 200 | 200 | PSI-mode early pressure |
| ro.lmk.thrashing_limit | 100 | 100 | thrash guard |

## Host systemd-oomd (/etc/systemd/oomd.conf)
DefaultMemoryPressureDurationSec=30s; container subtree
ManagedOOMMemoryPressureLimit=80% action none (monitor-only).
# WHY monitor-only (S34): host never SIGKILLs the container; pressure is
# forwarded to container lmkd via /run/halide/memory-pressure event + banner
# so the kill decision stays in the stack that understands adj scores.

## PSI thresholds (one instrumentation, two consumers - S34)
- Host monitors /proc/pressure/{cpu,memory,io} 10s windows via
  halide-psi-monitor.service.
- `memory some avg10 >20%` sustained 30s -> journal MEMORY-PRESSURE + metric
  (feeds jank dashboard; scroll-jank during PSI>20% classified expected-physics
  per ch.06 S14 pattern extended to memory).
- `memory full avg10 >5%` -> container lmkd aggressive pass + host defers
  non-critical batch (sync, dexopt, logrotate via ConditionMemoryPressure=).
- `io full avg10 >10%` during app launch -> UFS-clkscale audit (S15
  clkscale/hibern8 state dumped; io-stall with clocks gated is policy,
  without is driver).
- Test: stress-ng --vm 4 --vm-bytes 80% 5-min soak per RAM variant (PSI
  traces archived; kill order cached->empty->perceptible, never foreground;
  foreground kill = P0 with reproducer).

## Swappiness / watermarks / drop-caches discipline (S34)
- vm.swappiness=100 container (Android convention: anonymous->zram
  aggressively); vm.swappiness=60 host (page-cache protective).
- vm.watermark_boost_factor=15000, vm.watermark_scale_factor=125
  (reclaim-ahead for camera-preview concurrency; preview+display+iperf triple
  test S13 re-run after any watermark change with frame-drop delta attached).
- drop_caches in scripts BANNED except the S28 cold-cache boot test (any other
  `echo 3 > drop_caches` fails review with link here).

## Low-memory killer verification (per release, per RAM variant - S34)
- lmkd-test: fill to each minfree level; assert kill order +
  sys.boot_completed stays 1 + foreground app survives to PERCEPTIBLE boundary.
- 50-app open/close churn: no boot_completed flap, no host OOM journal.
- Camera 12MP burst during PSI>15%: no green frames (reclaim stall vs ISP
  stride disambiguation logged, ch.04 S9 adjacency).
- Results table (SEED - fill on first HW run):
- Footnote set required per ch.10 §12 on every filled row: unit label +
  firmware SHAs + ambient temp + run count with median (never mean alone) +
  calibration state of the meter. PENDING rows carry no numbers, so no
  footnote applies yet — the first HW run fills both together.

| Variant | Test | Result | Date | Notes |
|---|---|---|---|---|
| 4GB | lmkd-test levels | PENDING | - | seed |
| 4GB | 50-app churn | PENDING | - | seed |
| 4GB | 12MP burst @PSI>15% | PENDING | - | seed |
| 6GB | lmkd-test levels | PENDING | - | seed |
| 6GB | 50-app churn | PENDING | - | seed |
| 6GB | 12MP burst @PSI>15% | PENDING | - | seed |

## Swap wear math (WHY no disk swap, S34)
# UFS program/erase cycles ~3000 (TLC class); a 2GB swapfile at 50% daily
# rewrite = ~1TB writes/year on the userdata pool sharing the same dies as
# LUKS2 userdata (dm-crypt doubles write-amp: 2TB effective). zram costs
# CPU (measured above) but zero flash wear - hence zram-only v1.
