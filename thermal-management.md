# Thermal Management — Zones, Trips, Throttling Policy & Skin-Temp Discipline
**Parent: ch.02 §6, ch.10 §4 · Per-SKU data in `thermal/<sku>/` · Rule: throttle early, never lie about heat**

## 1. Zone inventory (fill per SKU from sysfs + stock comparison)

List every `/sys/class/thermal/thermal_zone*` (type, sensor, current trip points) + cooling devices (`cpufreq`, `devfreq`, `wlan`, modem-PA backoff where exposed). Missing-vs-stock audit: stock exposes N zones, HALIDE exposes M — gap explained per zone (driver missing with BUG link, or virtual-stock-zone with no hardware meaning — the latter documented once, not chased). Trip points committed in DT (`80-battery.dtsi` adjacent `thermal.dtsi` include) with hysteresis values + source comments (datasheet max-junction minus margin, margin stated).

## 2. Throttling policy (user-visible behavior specified, not emergent)

Order of engagement (each step logged at `THERMAL_*` journal tag for `halide-power top` visibility): (1) GPU/devfreq cap 80% (invisible in most UI), (2) big-core max-freq −20%, (3) display brightness −15% with user notice chip ("Cooling — brightness reduced", dismissible, re-shows if step 4), (4) modem PA backoff + hotspot client notice (throughput dip explained in-UI, not mystery slowness), (5) camera 4K/1080p60 features greyed with reason string (never a silent record-stop). Hard shutdown (PMIC `overtemp`) must never be the first signal the user gets — any dogfood report of sudden thermal shutdown without preceding steps = P0 policy bug.

## 3. Validation (30-min video + LTE, ch.10 §4 gate expanded)

Workload: 720p local video + LTE iperf + 200-nit display, 30 min, ambient 23±2°C, case-off AND case-on runs (cases add 3–5°C — both recorded). Metrics: clock traces (never below 70% at 30 min), skin-temp IR spots (SoC area + battery, ≤45°C report-only per ch.10 §4), battery-temp slope (charge+load combined run separately — charging gamer is the worst case, tested explicitly), throttle-step log (which steps engaged when — policy proof). Stock oracle same conditions (ratio table, not absolute bragging).

## 4. Sustained-performance UX contract

Phosh Settings → Battery shows thermal state (Normal/Warm/Throttled with the engaged step named — no black-box "phone slow"). Long-task apps (video record, hotspot) get `THERMAL_PRESSURE` hint via bridge/compositor channels so they can degrade gracefully (camera drops 60→30fps with on-screen note rather than tripping step 5 blind). Hint delivery tested in `tests/thermal-hints.sh` (forced-trip via debug sysfs + assert app-visible note ≤3s).

## Verification

- [ ] Zone inventory vs stock explained; 30-min workload passes clocks + skin gates; throttle steps user-visible in order; hint delivery ≤3s proven.
