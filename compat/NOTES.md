# COMPAT NOTES (ch.01 §22)
No superlatives without meter traces.
Claims need log + trace refs.
TODO: add measured results.
Unmeasured = TODO, not done.
Review on each release-train.

# Bridged/owned surfaces (ch.05 §29/§30, ch.07 §6/§12)
captive_portal_mode=0  # Android CaptivePortalLogin suppressed; NM owns portal login
hotspot_toggle=ALREADY_HANDLED  # host NM owns AP mode; Android tile mirrors read-only
apn_editor=READ_ONLY  # host MM owns APN; persist.halide.apn_override honored, never clobbered
vpn=HOST_ONLY  # kill-switch in security/nftables.conf; container egress fail-closed
bluetooth=HOST_HCI  # BlueZ/PipeWire own HCI; Android sees bridged HFP/A2DP state

