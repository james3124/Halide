#!/bin/sh -e
# halide-dns-merge -- single-resolver DNS merge (ch.05 section 32).
# Source: hybrid/debian/net/halide-dns-merge.sh (installed to /usr/sbin/).
# Host systemd-resolved is the single resolver; Android DNS is forwarded, never
# a second cache. Precedence: VPN DNS > NM per-connection DNS > fallback
# (9.9.9.9 only when no other, logged as DNS_FALLBACK). Idempotent: dispatcher
# may fire up twice on roaming flap; second run is a no-op (DNS_NOCHANGE).
# Exit contract: 0 merged / 1 bad args / 2 resolver tool missing.
IFACE=""; EVENT=""
while [ $# -gt 0 ]; do case "$1" in --iface) IFACE="$2"; shift 2;; --event) EVENT="$2"; shift 2;; *) shift;; esac; done
if [ -z "$IFACE" ] || [ -z "$EVENT" ]; then
  echo "usage: $0 --iface IFACE --event up|down" >&2
  exit 1
fi
if ! command -v resolvectl >/dev/null 2>&1; then
  echo "halide-dns-merge: resolvectl absent (builder only)" >&2
  exit 2
fi
SERVERS="$(nmcli -g IP4.DNS,IP6.DNS con show --active 2>/dev/null | tr ',' ' ' | tr '|' ' ')"
[ -n "$SERVERS" ] || { SERVERS="9.9.9.9"; logger -t halide-dns "DNS_FALLBACK iface=$IFACE"; }
if [ "$EVENT" = "up" ]; then
  resolvectl dns "$IFACE" $SERVERS
  resolvectl domain "$IFACE" "~."
  resolvectl default-route "$IFACE" yes
  /usr/sbin/halide-netd-bridge --push-dns "$(echo $SERVERS | tr ' ' ',')#$IFACE" || logger -t halide-dns "DNS_NOCHANGE iface=$IFACE"
else
  resolvectl revert "$IFACE" || true
  /usr/sbin/halide-netd-bridge --push-dns "9.9.9.9#fallback" || true
fi
exit 0
