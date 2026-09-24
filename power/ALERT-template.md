# Power ALERT template (power-regression-bisect S1: 3 consecutive nights beyond
# floor - single-night spikes are noise, no alert without sanity-green).
# Copy to power/ALERT-<date>.md when the nightly job fires.

Scenario: TODO (suspend-8h / screen-off-idle / video / LTE / GNSS)
Nights-beyond-floor: TODO (dates + CSV links: /srv/power/<date>.csv)
7-day-median: TODO-measured mA / TODO-measured % deep residency
Delta-vs-median: TODO-measured % (floor: +15% suspend / +12% idle / +10% active)
Noise-floor: TODO (+-5% suspend / +-4% idle / +-6% active network variance)
Lab-sanity: TODO-green (meter cal tag + ambient probe via halide-lab-sanity)
Ambient-log: TODO (csv path)
MANIFEST-delta: TODO (good <manifest-A> -> bad <manifest-B> link)
WA-factor-audit: TODO-green / WA-DRIFT (halide-wa-audit, appendix-03B baseline)
Suspect-layer: TODO (kernel / HAL-blob / app-layer-bridge, see bisectVerdict)
Verdict-file: power/bisect-<date>.md (blamed commit + signature + both-reps CSV)
Rollout-link: S1+ ALERT arms OTA auto-halt input (ch.09 S9); exception needs
  dogfood justification: TODO (none open = ship-blocked)
