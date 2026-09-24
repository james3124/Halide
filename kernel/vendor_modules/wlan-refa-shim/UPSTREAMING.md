# wlan-refa-shim UPSTREAMING.md (ch.03 §4/§20/§27)
# Status: needs rework (BT SCO btattach cold-boot quirk + firmware handshake not in upstream shape).
# Upstream thread: TODO-lore-link (required before next quarterly carry review, §27).
# Owner: halide-kernel. Removal release: r3. Consumes KMI symbols: qrtr_endpoint_register (pinned).
# KUnit: TODO-link suite (probe fail -> -EPROBE_DEFER, suspend balanced) — required by §23/§27.
# Power note: suspend callback present (NO-SUSPEND-IMPACT not claimed).
# Second-SKU: UNTESTED on REF-B (ticket TODO).
