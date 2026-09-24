# panel BIST modes per variant (ch06 s24) - trust panel pipeline before OS
# color-bar: DDIC-generated bars (bypass DSI payload). Bars clean + OS corrupt =
#   DSI/link/software fault. Bars corrupt = panel/DDIC/power fault. Run FIRST.
# solid-color R/G/B/W/K + 5-shade gray ramp: stuck-line/pixel hunt, banding-vs-dither.
# sleep-in/out + display-on/off sequences: DDIC init-code validation (wrong
#   exit-sleep delay = black-screen-UART-alive). BIST proves DDIC alive first.
# ESD status regs (0x0A/0x0D-class RDDST/RDDPM): post-ESD triage - BIST-readable +
#   OS-dead = link re-train; BIST-dead = panel power/DDIC.
# Commands (exact per variant, tribal DSI knowledge committed):
#   color-bar: TODO-device: DSI-command tool line for variant-A
#   solids: TODO-device: R/G/B/W/K page commands
#   exit->OS handoff re-init sequence version: TODO-measured: vN (partial re-init
#     shows half-image/tearing; versioned with init-code)
# Factory station: BIST color-bar + solid-white on line, 8s budget + panel-ID read
#   (variant detection s11) before OS flash. Photo-archive bars+solids, 30-day retention.
# Status: UNMEASURED - bring-up + RMA-display-track runs pending.
