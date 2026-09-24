# BOUNDARIES.md — trust boundary between host (Debian/systemd) and Android container (ch.05 §19, ch.07 §1)

## The rule

The host is the single master of real hardware:
- Modem: host owns it exclusively via ModemManager (`telephony/mm-config.txt`: single-stack-only, no oFono, no second RIL master). Android reaches the modem only through `/run/halide/ril.sock` (ch.07 §1).
- Network: host NetworkManager owns Wi-Fi/LTE; Android netd is a translation client (ch.05 §16). No double NAT, no second DHCP.
- Audio: host PipeWire owns ALSA; container has no `/dev/snd` (absence is the contract test, ch.05 §19).
- Ban on dual masters: for every resource exactly one stack decides. The RIL-MM single-stack guard means Android RIL may *request*, never *own*; host may freeze all new MO traffic with `DENIED-radio-not-ready` during drain (ril_bridge.py RadioState).

## Socket registry (mirrors bridges/SOCKETS.md — registry there is normative)

| Socket | Direction | Allowed messages | Threat note |
|---|---|---|---|
| /run/halide/prop.sock | android->host | GET/SET allowlisted keys (bridges/prop-allowlist.txt) | compromised container can only move allowlisted props |
| /run/halide/ril.sock | android->host | DIAL/HANGUP/SMS_SEND/DATA_ENABLE; DENIED when radio draining | host may always refuse: single-master modem |
| /run/halide/audio.sock | android->host | ROUTE/VOLUME/MUTE on media/call/alarm; call preempts media | audioserver compromise cannot touch host mixer directly |
| /run/halide/perm.sock | bidir | GRANT/REVOKE <pkg> <perm>; SYNCED ≤10s | one consent source, atomic, no diverging counters |
| /run/halide/composer.sock | android->host | frame descriptors + fences only | no direct /dev/dri for container |

Managed in code (bridge py in bridges/), registered in SOCKETS.md, audited by
`scripts/socket-audit.sh`. Sockets not in SOCKETS.md do not ship (ch.05 §10).

## File/device boundaries (ch.05 §19 matrix)

- `/run/halide/*`: bridge sockets, `0660 root:halide-bridges` + SO_PEERCRED allowlist.
- `/dev/binderfs`, `/dev/dri`: container bind via device allowlist only.
- No `/dev/snd` in container (audio proxied through audio.sock, ch.05 §19).
- `/home/halide`: never mounted into container; share-bridge FD passing only.
- `/data/android`: container rootfs backing; host reads read-only during backup only.
- Persist/EFS/calibration partitions: host-only; container requests go through shims.

## Audit

`scripts/socket-audit.sh` + A/B tests in `bridges/tests/*_contract.sh` are the
gate: no contract test, no merge (ch.05 §9). Changes to any boundary require
SOCKETS.md + this file updated in the same MR, or `boundary-check` fails.
