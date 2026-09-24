#!/bin/sh -e
# 90-halide-netd: NM -> Android netd shim. Args: <iface> <event>.
# Source: hybrid/debian/net/dispatcher-90-halide.sh (installed to
# /etc/NetworkManager/dispatcher.d/90-halide-netd, root:root 0755).
# Dispatcher scripts are advisory: exit non-zero never blocks NM (ch.05
# section 32). Failures log + count DISPATCHER_FAIL; the connection still
# comes up (host networking outlives the container, always).
# Exit contract: 0 always (advisory) / 1 bad args (logged) / 2 bridge absent.
IFACE="${1:-}"; EVENT="${2:-}"
BRIDGE_SOCK="/run/halide/netd.sock"
log() { logger -t halide-netd "iface=$IFACE event=$EVENT $1"; }

if [ -z "$IFACE" ] || [ -z "$EVENT" ]; then
  log "bad-args"
  exit 1
fi
if ! command -v halide-netd-bridge >/dev/null 2>&1; then
  log "bridge-absent skip"
  exit 2
fi

case "$EVENT" in
  pre-up)
    # veto Android-held routes before NM commits (prevents dual-default flap).
    /usr/sbin/halide-netd-bridge --freeze-android-routes --iface "$IFACE" || log "freeze-failed"
    ;;
  up)
    ADDRS="$(nmcli -g IP4.ADDRESS,IP6.ADDRESS con show --active "$CONNECTION_UUID" 2>/dev/null || true)"
    GW="$(nmcli -g IP4.GATEWAY,IP6.GATEWAY con show --active "$CONNECTION_UUID" 2>/dev/null || true)"
    METERED="$(nmcli -f GENERAL.METERED -t con show --active "$CONNECTION_UUID" 2>/dev/null | head -1)"
    /usr/sbin/halide-netd-bridge --push --iface "$IFACE" --addrs "$ADDRS" --gw "$GW" --metered "$METERED" || log "push-failed DISPATCHER_FAIL"
    /usr/sbin/halide-dns-merge --iface "$IFACE" --event up || log "dns-merge-failed DISPATCHER_FAIL"
    log "pushed addrs=$ADDRS metered=$METERED"
    ;;
  down|pre-down)
    /usr/sbin/halide-netd-bridge --withdraw --iface "$IFACE" || log "withdraw-failed DISPATCHER_FAIL"
    /usr/sbin/halide-dns-merge --iface "$IFACE" --event down || log "dns-revert-failed DISPATCHER_FAIL"
    log "withdrawn"
    ;;
  vpn-up)
    # VPN owns default route both stacks; slave Android to host TUN.
    /usr/sbin/halide-netd-bridge --push-vpn --iface "$IFACE" --tun "$VPN_IP_IFACE" || log "vpn-push-failed DISPATCHER_FAIL"
    log "vpn-slaved tun=$VPN_IP_IFACE"
    ;;
  vpn-down)
    /usr/sbin/halide-netd-bridge --restore-default --iface "$IFACE" || log "vpn-release-failed DISPATCHER_FAIL"
    log "vpn-released"
    ;;
  connectivity-change)
    /usr/sbin/halide-portal-announce --iface "$IFACE" --state "$CONNECTIVITY_STATE" || log "portal-announce-failed DISPATCHER_FAIL"
    ;;
esac
exit 0
