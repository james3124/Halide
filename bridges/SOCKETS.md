# SOCKETS.md — registry stub (every socket documented or it doesn't ship, ch.05 §10)
# Full registry lives in hybrid-os-plan/bridges/*.md. Phone edits the table, builder audits with ss -x.

| Socket | Owner | Direction | Purpose |
|---|---|---|---|
| /run/halide/prop.sock | platform | android->host | prop→dbus get/set (allowlist only) |
| /run/halide/ril.sock | telephony | android->host | RIL→MM single-stack, host owns modem |
| /run/halide/audio.sock | platform | android->host | AudioFlinger→PipeWire bridge |
| /run/halide/perm.sock | platform | bidir | atomic permission sync ≤10s |
| /run/halide/composer.sock | graphics | android->host | SurfaceFlinger→Wayland frames + fences |
| /run/halide/netd.sock | platform | android->host | netd→NetworkManager (VPN egress fail-closed) |
| /run/halide/input.sock | platform | host->android | Wayland input events→container (touch/key) |
| /run/halide/wifi.sock | platform | bidir | NM state mirror (STA/AP/metered), hotspot ALREADY_HANDLED |
| /run/halide/bt.sock | platform | bidir | BlueZ state mirror, bridged HFP/A2DP (host owns HCI) |

## State files (not sockets — no `ss -x` entry; producers/consumers named)
| Path | Producer | Consumer | Purpose |
|---|---|---|---|
| /run/halide/memory-pressure | halide-psi-monitor.service | container lmkd bridge | PSI stall forwarding, host never SIGKILLs container (ch.03 §34) |
| /run/halide/metered.state | halide-wifi-bridge.service | netd bridge / OTA | metered-link mirror for OTA + hotspot policy (ch.05/ch.09) |
| /run/halide/degraded-banner | halide-android-prepare | halide-crash-banner.service | degraded-boot flag (modem FW async timeout path, ch.03 §28) |
| /run/halide/crash-banner.state | halide-crash-banner.service | Phosh banner | 3-strike crash banner state (ch.05) |
| /run/halide/emergency-callback-until | halide-drain | ril bridge | emergency-callback window respected by drain ladder (ch.07) |
| /run/halide/slot-health | halide-firstboot-check | update_engine | A/B slot health marking (ch.09) |
