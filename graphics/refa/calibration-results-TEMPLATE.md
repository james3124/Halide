# display calibration results (display-calibration-procedure) - TEMPLATE
# SKU: refa | Panel variant: variant-A | Date: TODO | Operator: TODO
# Lab rig: graphics/lab-rig.json cal ID TODO | Meter: TODO model+serial+cal-date
# Entry gate: modetest -M msm preferred mode OK; kmscube 60s no underrun.
# 1. Lux curve (7 pts host-driven, gammastep off, overlay off):
#    TODO-measured table (host, android mirror, lux median x3, nits, notes).
#    Level 0 must be <2 nits or file light-bleed bug.
# 2. White/gamma: TODO-measured CCT/x/y (target D65 +-300K...6500K+-500 per proc),
#    16-step gamma fit TODO + residual. measured:false if datasheet-only (amber).
#    Night-light off; one 4500K gammastep run archived separately.
# 3. Brightness sync: Phosh slider 0/25/50/75/100% -> Android mirror <=2 within 2s,
#    lux monotonic. HBM host-owned; container cannot force HBM (dumpsys cap proof).
#    AOD off v1 (power reason logged in display-power.md).
# 4. Color agreement: grim vs screencap mean per-channel diff TODO (<6/255 gate).
# 5. Variant guard: wrong-panel boot halts named-variant error (halide-display-verify).
# Status: UNMEASURED - no hardware numbers in this template. Re-cal triggers:
# panel lot / backlight driver / DT timing change / dE>6 / 12-month age.
