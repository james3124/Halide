# DP alt-mode 50x matrix (ch06 s15 Phase-4 sketch - v1 single panel only)
# v1 rule: single panel DSI-1 only. Any second-display code without PHASE4-DISPLAY
# ADR is closed with link to ch06 s15. This file stages entry-condition (b) only.
# Entry (b): SKU with verified DP-alt-mode HW: role-switch both orientations +
# drm_info DP connector appear/disappear 50x without wedge (ch04 s21 USB drill ext).
# Matrix template (lab, sacrificial, dwc3 role + DP mux present per ch02 s3 USB row):
# run,orientation,role_to,dp_connector,appear_ok,disappear_ok,wedge_bool,notes
# 1..50 rows TODO-measured. PASS bar: 50/50 appear+disappear, 0 wedge.
# Other entries (a) dogfood need counts (b) here (c) dual-pipe power metered
# (d) security review lockscreen-wins 50/50 per output - all four required.
# Status: UNMEASURED - v1 non-gate, no code until all four met.
