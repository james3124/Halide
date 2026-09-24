# Low-Spec Tier — 4GB RAM / 32GB Storage Is the Baseline, Not the Afterthought
**Parent: ch.01 §7 DoD, ch.02 matrix · Status: BINDING — a release that can't run here doesn't ship · Owner: Platform + BSP**

## 1. The rule (one sentence)

HALIDE v1 must be smooth on a 4GB-RAM / 32GB-storage phone; higher-spec devices get headroom, never requirement creep. Any MR that breaks the budgets below fails CI with the delta named (budgets enforced by tooling per §4, not by intentions).

## 2. RAM budget — 4,096 MB accounted to zero (measured, not estimated)

| Consumer | Budget (MB) | Notes |
|---|---|---|
| Kernel + drivers + ion/dma carveouts | ≤350 | carveouts in DT committed per SKU; growth needs BSP sign |
| systemd host base (no GUI) | ≤250 | services allowlisted (ch.05 packages.host); each new daemon shows its PSS |
| Phosh + compositor + GNOME shell stack | ≤450 | measured post-login idle; leaks caught by soak slope-alerts (ch.10 §15) |
| PipeWire + WirePlumber + audio bridges | ≤120 | |
| NetworkManager + ModemManager + bridges | ≤150 | |
| Android container framework (system_server + natives, pre-app) | ≤1,100 | single active user, no work profile (ch.05 §13 boundary already) |
| Foreground app headroom (1 Android + 1 native) | ≥900 | the smoothness reserve — LMK protects this, not the cached tail |
| GPU/ion dynamic + file cache + margin | rest (~770) | zram backs the tail (see §3) |
| **Total committed** | **≤3,320 hard + reserve** | over-budget MR prints the fattest process (like image-size rule, ch.01 §16) |

OOM/LMK discipline: `lmkd` + PSI-driven kills target cached background apps first, then background services, NEVER the foreground app or telephony stack (kill-priority tiers committed in `lmkd/<sku>/priorities.conf`; dogfood "foreground app killed" = P0). Cold-start of a killed background app ≤2s median (the relaunch must be fast enough that LMK is invisible — measured in ch.01 §16 launch harness).

## 3. Memory stretchers (all on, all measured — §cost rule from 08 §16 applies in spirit)

zram (lz4, 1.5GB device, swappiness tuned per SKU — not distro-default) + zswap off (one comp layer, not two — measured choice, recorded). `init_on_free` stays ON (security §16 not negotiable for RAM savings — say it here so nobody proposes it later). Kernel same-page merging (KSM) evaluated per SKU with dedup-ratio numbers (ships only if >150MB saved under dogfood load — KSM's CPU cost on little cores must show its receipt). Dex preopt profile-guided (`speed-profile`, not `speed` — full AOT is a storage hog, §4). No swap partition/file on flash (wear + stall unpredictability — zram only).

## 4. Storage budget — 32GB flash (~29GiB usable) laid out

| Partition set | Size | Format/notes |
|---|---|---|
| boot+vendor_boot+vbmeta+dtbo (×2 slots) | ~300MB | fixed |
| super (system/vendor/product, erofs compressed) | ≤6GiB (cap, down from 9 — §5 trims fund this) | erofs + dedupe audited per release |
| host_a/host_b (Debian erofs) | ≤2.2GiB each | curated package set (ch.05 §15 Flatpak story respects this) |
| persist/misc/efs/modemst | ~100MB | never touched by OTA |
| userdata (LUKS) | remaining ~18GiB | user data + container data; low-storage warnings at 2GiB/1GiB/500M with per-app breakdown |
| **Factory image total** | **≤11GiB** | leaves ~18GiB user space on 32GB — the number we publish, not "32GB supported*" |

OTA on 32GB: A/B slots already counted above (no extra download partition — payload streams to inactive slot; download needs 2.5GiB free, checked pre-download with honest error, resume supported ch.09 §9).

## 5. What 4GB SKUs trim or defer (named cuts, not silent rot)

Single-active-SIM only (DSDS already Phase-4, ch.07 §17 — no conflict). No preinstalled Flatpak bundle beyond the ch.05 §15 core set (store browses, doesn't preload). Camera aux-sensor features (wide/tele) degraded-first on 4GB (main sensor gate unchanged). `halide-power top` sampling 5s instead of 2s on 4GB (observer overhead budgeted too). Nightly VIRT matrix includes a 4GB-memory-limited QEMU run (cgroup-capped builder job — regressions caught before hardware). Anything else proposed for the axe goes through scope-change REDUCTION class (ch.01 §17 — cuts recorded with strikethrough, never silent).

## 6. Smoothness gates on 4GB hardware (the "it's smooth" proof, all automated)

Scroll jank <5% missed vsync on REF 4GB unit (ch.06 §10 matrix runs on the 4GB SKU, not just the 8GB lab queen). App switch (Android→native→Android) ≤800ms p95. Incoming-call UI ≤1.5s from RIL event on memory pressure (90% full synthetic load — the test that matters). 72h soak on 4GB (ch.10 §15) with leak-slope alerts halved vs 8GB (less headroom = tighter slopes). Any gate red on 4GB while green on 8GB = 4GB-specific P1 (not "works on my unit" — the 4GB unit is the reference, ch.10 §7 oracle rule extended: stock comparison runs on the same 4GB class).

## Verification

- [ ] `scripts/budget-check.sh` (RAM PSS table + image sizes) green in CI per release; 4GB-QEMU matrix job green; 72h 4GB soak slope-clean.
- [ ] Factory image ≤11GiB measured; low-storage warnings demonstrated at all three thresholds.
