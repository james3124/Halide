# flicker test checklist per release (ch06 s18/s26, CAM240 gate)
# Rig photo per bench committed; method column CAM240 vs SCOPE never averaged.
# - [ ] TODO-measured: 240fps clips at 10/25/50/100% slider + min-usable floor (5s each, full-white, night-light off, auto-brightness off, ambient <10 lux logged, exposure locked white~80% zebra, settings screenshot archived)
# - [ ] TODO-measured: halide-flicker-scan CSVs (frame,luma): PASS p-p<=3% + FFT<2x noise; MARGINAL 3-8% (ships only with BUG+variant list); FAIL >8% or rolling bands (contact-sheet PNG archived 30d)
# - [ ] TODO-measured: lux-meter linearity 5+ pts into backlight curve (PWM-low-end correction committed)
# - [ ] TODO-measured: suspend/resume backlight restore +-1 step within 1s (no resume-to-full-blast)
# - [ ] TODO-measured: hybrid panels repeat with dc_crossover forced both sides (2 CSVs); charger-vs-battery repeat (charger-only flicker -> charger/PMIC, not dimming)
# Release artifact: graphics/<sku>/flicker-<ver>-CAM240.zip (4 clips + 4 CSVs + sheets + curve hash). Verdict: UNMEASURED until zip linked.
