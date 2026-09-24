# 05 — Debian Userland, systemd-as-PID1 & Dual-Init Bridges
**Budget: 80,000 chars · Phases: 1–2 · Owner: Platform · Base: Debian trixie snapshot + systemd + Phosh**

## 1. Image composition

Host rootfs built with `mmdebstrap` from a pinned snapshot (`snapshot.debian.org` timestamp in `MANIFEST.debian`). No `task-desktop`; explicit package list in `debian/packages.host` (~450 pkgs: kernel, systemd, NetworkManager, ModemManager, PipeWire, WirePlumber, Phosh, Calls, Chats, Epiphany/Firefox-esr, Flatpak, `halide-*` bridges).

```bash
mmdebstrap --variant=essential --arch=arm64 \
  --include=$(paste -sd, debian/packages.host) \
  --hook-dir=debian/hooks/ \
  trixie "$SNAPSHOT_URL" out/debian-rootfs.tar
```

Hooks: set hostname `halide`, create `halide` user (UID 1000), enable units, install keys, write `/etc/halide-release` (version, manifest SHAs, device).

## 2. systemd unit graph (PID1 = systemd, Android = managed container)

```
sysinit.target
 └─ halide-early.service (mount binderfs, kmsg, pstore-collect)
     └─ systemd-udevd → dri/binder/qrtr nodes
         └─ halide-android.service (LXC start, type=notify, restart=on-failure)
             ├─ halide-prop-bridge.service (getprop↔dbus)
             ├─ halide-netd-bridge.service (netd↔NM, single-stack)
             ├─ halide-audio-bridge.service (AudioFlinger↔PipeWire)
             ├─ halide-ril-bridge.service (telephony↔ModemManager)
             └─ phosh.service (graphical.target)
```

`halide-android.service` excerpt:

```ini
[Unit]
Description=HALIDE Android container
After=systemd-udevd.service network-pre.target
Requires=dev-binder.device dev-dri-card0.device
[Service]
Type=notify
NotifyAccess=all
ExecStartPre=/usr/sbin/halide-android-prepare
ExecStart=/usr/bin/lxc-start -n android -F
ExecStop=/usr/bin/lxc-stop -n android
Restart=on-failure
RestartSec=5s
StartLimitBurst=3
[Install]
WantedBy=multi-user.target
```

Crash policy: 3 rapid crashes → stop auto-restart, drop to Phosh with "Android unavailable" banner + one-tap log export (never boot-loop the whole phone).

## 3. Identity/UID mapping

Host `halide` (1000) ↔ Android `system`/`radio` via idmapped mounts + explicit ACLs, not 1:1 UID reuse. Binder allowed only via bridge sockets in `/run/halide/` with `0660 root:halide-bridges`. Document every cross-boundary socket in `bridges/SOCKETS.md` (path, owner, protocol, threat note).

## 4. Bridges (each: protocol, direction, failure mode)

**prop-bridge:** polls `getprop` (sys.boot_completed, telephony, battery) → D-Bus `org.halide.Android`. Read-only except allowlisted `setprop` (locale, timezone). Test: change timezone in Settings → `getprop persist.sys.timezone` follows ≤5s.

**netd-bridge:** single-stack rule — NetworkManager authoritative. Android `netd` calls translated (interface up/down, routes, DNS) or rejected with `PERMISSION_DENIED` + host log. VPN: whichever side establishes TUN owns default route; other side slaved. Test: host VPN on → Android traffic egresses VPN (verify via `curl` inside container showing VPN IP).

**audio-bridge:** UNIX socket `/run/halide/audio-proxy`; Android opens streams, host mixes. Call preemption: `halide-call-state` signal mutes media + routes modem PCM. Test matrix in ch.04 §3.

**ril-bridge:** Android Telephony events (call state, SMS rx, signal) ↔ ModemManager D-Bus. SMS store: host is store of record v1 (Android reads via bridge; document direction). Test: 10 SMS each direction, airplane toggle recovery ≤60s.

**permission-bridge:** one prompt → writes both xdg-permission-store and Android grant (`pm grant`). Revoke propagates both ways ≤10s. Test script `tests/permission-sync.sh`.

**clipboard/share-bridge:** Android→Linux share guaranteed v1 (intent → `xdg-open`); reverse best-effort with format table (text/URI guaranteed, rich content documented).

## 5. Phosh integration

Phosh is the shell; Android apps appear via `.desktop` shims generated from `pm list packages` (`halide-android-drawer` daemon). Badge = small robot glyph; long-press → "App info (Android)" opens bridged permission page. Android notifications forwarded to `phosh-notification-daemon` via `NotificationListenerService` → D-Bus (title/body/icon; actions v1: open only).

Calls UI: GNOME Calls owns dialer; incoming RIL events ring Calls even if Android Dialer installed (Android Dialer hidden from drawer v1 to avoid dual-dialer confusion).

## 6. Updates & data separation

`/userdata` split: `/home` (Debian) + `/data/android` (container). OTA never formats either; factory reset wipes both with two confirmations + printed warning. Backup v1: `halide-backup` exports contacts/SMS/photos list + `restic` hook for home dir (document what is NOT backed up: app-internal Android data without backup agent).

## 7. Failure table

| Symptom | Check | Fix |
|---------|-------|-----|
| Phosh up, Android badge apps missing | `systemctl status halide-android*`, `lxc-info` | container down → journal; drawer daemon caches last-known list, never empty silently |
| Timezone/locale drift | `timedatectl` vs `getprop` | prop-bridge allowlist missing prop; add + test both directions |
| VPN leaks on one side | `ip route` host vs `dumpsys connectivity` | route metric conflict; fix bridge priority table |
| Double audio (echo) | `pw-top`, `dumpsys audio` | proxy + direct ALSA both open; kill direct, enforce proxy-only via udev rule |

## 8. Debian snapshot & package governance (normative)

Snapshot pin: `SNAPSHOT_URL=https://snapshot.debian.org/archive/debian/20260210T000000Z` (example; actual stamp in MANIFEST.debian, never `testing` floating). `packages.host` is allowlist-only (~450 lines, each with `WHY:` comment); adding a package requires the comment or CI rejects the MR. Quarterly snapshot bump procedure: (1) bump stamp in sandbox, (2) full rebuild, (3) boot + radio + camera smoke, (4) record upgraded-package diff in release notes, (5) 48h dogfood before promotion. Security pocket: `snapshot.debian.org` security updates are cherry-picked out-of-band with `debsecan` report attached to the MR — never silently skip a CVE because "snapshot freeze".

`debian/hooks/` ordered: `10-hostname-user.sh` (user `halide` UID 1000, groups `netdev,bluetooth,audio,video,render,plugdev,halide-bridges`), `20-units.sh` (`systemctl enable` the graph in §2, mask `ModemManager`-fighting units), `30-keys.sh` (install release pubkeys to `/usr/share/halide/keys`, never private), `40-release.sh` (write `/etc/halide-release`: version, MANIFEST SHAs, SKU, builder digest, `ro.build.fingerprint`-equivalent), `50-clean.sh` (purge docs/locales outside top-12, `apt clean`, truncate machine-id so each device generates its own on first boot).

First-boot (`halide-firstboot.service`, `ConditionFirstBoot=yes`): generate machine-id, SSH host keys (dropbear off by default — document remote-debug opt-in with pairing code, never passwordless), LUKS encrypt userdata if not already (ch.08), expand userdata to full flash, set locale/timezone from EL0 MCC or user pick, enroll lockscreen PIN (mandatory before modem enable — stolen-device rule).

## 9. Bridge daemon specification (each bridge ships this)

Every `halide-*-bridge` is a systemd-managed daemon (Rust or Go; no Python in the hot path — latency + sandbox reasons) with: `--self-test` mode (runs without container, exit code contract), structured logs (`CODE` + `BRIDGE` + `PEER` fields for journal filtering), Prometheus-style metrics on `/run/halide/<name>.metrics` (messages in/out, errors, last-sync age — scraped by `halide-health`), and a `BUS` contract test in `bridges/tests/<name>_contract.sh` that runs in CI against a fake peer (container stub). Contract tests are the gate: no contract test, no merge.

**prop-bridge detail.** Polls `getprop` over vsock/pipe every 2s + subscribes to `sys.boot_completed`/`gsm.*`/`battery.*` change events; republishes on D-Bus `org.halide.Android` (`/org/halide/Android`, interface with `PropertiesChanged`). Write path: allowlist only (`persist.sys.timezone`, `persist.sys.locale` v1 — exact list in `bridges/prop-allowlist.txt`); everything else returns `org.halide.Error.Denied` + audit log line. Conflict rule: host clock/locale always wins (documented; Android `auto-time` slaved to host `timedatectl set-ntp`).

**netd-bridge detail.** Intercepts Android `netd` binder calls at the proxy (`libnetd-halide`): `interfaceSetCfg`, `networkAddRoute`, `setDnsServersForNetwork` are validated against NM state — matching requests pass, contradictory ones (e.g., Android tries to bring down `wlan0` NM manages) are rejected with `PERMISSION_DENIED` + `journalctl` line + `dumpsys connectivity` shows `HALIDE-BRIDGED` marker so testers know the path. DNS: host `systemd-resolved` is the single resolver; Android DNS queries are forwarded (no second cache with different TTL semantics). Meteredness: host connection meter flag mirrored to Android `ConnectivityService` (so big-download guards actually work).

**audio-bridge detail.** See ch.04 §8 for HAL side; host side is a PipeWire client (`halide-audio-daemon`) owning `alsa_output`/`alsa_input` exclusively (udev rule `SUBSYSTEM=="sound", GROUP="audio", MODE="0660"` + container has no direct ALSA node — enforced by LXC device list, not trust). Call preemption signal `org.halide.CallState` (`IDLE/RINGING/OFFHOOK`) mutes `Multimedia` role −20dB (duck, not hard cut — UX rule) and routes modem PCM with the per-SKU gains from `audio/<sku>/call-gains.conf`.

**ril-bridge detail.** D-Bus both directions: Android `TelephonyRegistry` events (call state, signal, SIM) ←→ ModemManager `org.freedesktop.ModemManager1` signals. SMS: host store of record; inbound SMS written to Chats DB then mirrored to Android provider via `SmsProvider` insert (read-only mirror flag set so Android apps can't double-send from a stale copy). Outbound from Android app → bridge intercepts `SEND_SMS` intent → routes through MM (`mmcli --messaging-create-sms`) and reports via `sentIntent` — so billing/dual-SIM accounting stays single. Airplane mode: host `rfkill` is truth; Android toggle forwarded to host (never local-only).

**permission-bridge detail.** Mapping table (`bridges/permission-map.csv`): `LOCATION↔geo:9100+Android FINE`, `MICROPHONE↔audio-record+RECORD_AUDIO`, `CAMERA↔camera+ CAMERA`, `CONTACTS↔eds+READ_CONTACTS`, `SMS↔chats+READ_SMS`, `STORAGE↔xdg-documents+READ_MEDIA_*`. Grant writes both stores atomically (two-phase: stage both, commit both, rollback on either failure — never half-granted). Revoke ≤10s both ways (timer test in `tests/permission-sync.sh`: grant→check both→revoke→check both, 20 iterations, 0 desync allowed).

**notification-bridge detail.** Android `NotificationListenerService` (`HalideListener`, system-signed, no INTERNET) forwards (title/body/icon/package/timestamp) to `org.freedesktop.Notifications` via D-Bus; actions v1: `open` only (replies are Phase-4). Rate-limit 20/min per package (spam guard) + DND mirrors host state. Test: 50 notifications mixed packages, order + badge counts match.

**clipboard/share detail.** Android→host: `SEND` intent captured by `HalideShare` activity → `xdg-open`/portal (text/URI guaranteed; images via `/run/halide/share/` FD pass; rich/HTML best-effort with format table in Settings → Sharing). Host→Android: text/URI via `am broadcast` to bridge receiver (guaranteed); binary reverse is Phase-4 (documented gap, not silent).

## 10. SOCKETS.md registry (every socket documented or it doesn't ship)

`bridges/SOCKETS.md` rows: path, type (STREAM/DGRAM/vsock), owner:group + mode, peer UID check (`SO_PEERCRED` allowlist), protocol (length-prefixed protobuf? newline JSON? — one per socket, versioned), max message size (reject bigger — fuzz target), timeout + backpressure policy (drop-newest vs block with deadline — block-without-deadline is a bug), and a one-line threat note ("compromised audioserver can…"). CI cross-checks: a socket present on device but absent from SOCKETS.md fails the release (script `scripts/socket-audit.sh` compares `ss -x` output).

## 11. Phosh/drawer deep-dive

`halide-android-drawer` watches `pm list packages -3` (third-party) + system allowlist (`F-Droid`, `Aurora`, `OpenCamera`, Settings-bridge); generates `~/.local/share/applications/android-<pkg>.desktop` (`Exec=halide-android-launch <pkg>/<activity>`, `Icon=` from APK via `aapt dump badging` cached in `~/.cache/halide/icons/`, robot-badge overlay). Uninstall from drawer = `pm uninstall` via bridge (with Android confirm activity, never silent). Hidden list (`drawer/hide.conf`): stock Dialer, stock SMS, stock Browser (duplicates of host apps — unhide documented for testers via `halide-drawer --show-all`).

Launch path: `halide-android-launch` → bridge `am start` → `halide-composer` maps window (ch.06) → 3s spinner with package icon, then window or structured error card ("Android unavailable — Export logs" button, never a bare spinner forever).

Calls/Chats ownership UX: incoming call rings GNOME Calls full-screen even if Android Dialer installed; Android-side call UI suppressed via `TelecomManager` default-dialer pin (document the pin command; testers verify `dumpsys telecom` shows host dialer default after every OTA — OTA must not reset it).

## 12. Backup/restore/factory-reset runbook

`halide-backup` (Settings → Backup): exports contacts (vCard), SMS (XML), call log (CSV), photos file list + hashes, `restic` snapshot of `/home/halide` (excluding caches), and an Android-side manifest (`pm list packages` + versions — data only for apps with backup agents; gap documented in the export report). Restore reverses with version-skew warnings (newer→older blocked with explanation). Factory reset: two confirmations + typed SKU + crypto-erase (ch.08) + reboot to first-boot; generates wipe attestation line in recovery log (enterprise requirement P3).

OTA data-safety invariant: `halide-ota-pre` snapshots bridge databases + `/home` manifest; post-OTA `halide-ota-post` verifies counts match within tolerance (contacts/SMS exact, media hash-sampled); mismatch → slot rollback + report (ch.09 §4 health-check extended).

## 13. Drawer edge cases (the details users actually hit)

Duplicate install (F-Droid + Aurora same package): single drawer entry (first-seen source wins, source chip shows both; uninstall offers per-source removal — never orphan the other copy silently). Renamed app (label change in update): shim follows `component`, not label (label cached separately — update changes icon/label in place, position preserved). Disabled package (`pm disable`): drawer greys with "disabled" tag + enable action (not vanish — vanishing reads as data loss). Work-profile/secondary-user packages: hidden v1 with Settings note (multi-user Android inside single-user host is Phase-4 — the boundary is drawn here so nobody builds on it accidentally). Icon fetch failure (corrupt APK): robot-badge placeholder + `ICON_FAIL` metric (never a missing-invisible entry). Drawer search indexes both stacks (one search box — ch.01 §9 UX principle enforced in code review: any second search box is a review fail).

## 14. OTA data-safety invariant expanded (what "preserves data" provably means)

Pre-OTA snapshot (`halide-ota-pre`): counts (contacts exact, SMS exact, media file-count + 5% hash sample, home-dir manifest) + bridge DB checksums + `examples of one`: sample contact vCard + newest SMS timestamp (sanity-readable, redacted of content in logs). Post-OTA (`halide-ota-post`): recount + compare — contacts/SMS exact-match required (any delta = rollback, no tolerance — counts don't drift on upgrade), media hash-sample 100% (count ±0 + sample green), home manifest: dotfiles exact, caches allowed-dirty (cache whitelist in `ota/cache-whitelist.txt`). Report shows the table to the user ("42 contacts, 1,208 messages, 312 photos — all preserved ✓") — the checkmark is computed, not decorative (tapping it shows the counts).

## 15. Flatpak & native app story (Linux apps first-class, not terminal-only)

Preinstalled native set (image-size budgeted, ch.09): Calls, Chats, Epiphany (or Firefox-ESR per footprint decision recorded with numbers), Settings, Terminal, Camera (libcamera reference UI), Maps (geoclue+NMEA), Backup. Flatpak (Flathub filtered remote — `flatpak remote-list` shows `halide-filtered` with allowlist rationale per app class; unfiltered Flathub one-tap-addable with warning): target 20 curated mobile-adapted apps by Phase-3 (each graded like compat-matrix: WORKS/DEGRADED with small-screen notes). `apt` fully present (P2 story ch.01 §11) with mobile-data meter warning on large installs (NM meter flag reused — 500MB `dist-upgrade` on LTE asks first). Default-app mapping: Android apps never silently become defaults (browser/phone/SMS/camera defaults are host apps; per-link "open with" chooser offers Android targets with badge — user assigns, system never guesses).

## 16. Bridge safe-modes (graceful degradation designed, not improvised in incidents)

Each bridge ships `--safe-mode` (IR runbook §2 containment references these): ril-safe (voice-only CS, data via host-tethered path, SMS store-and-forward with user notice — used when ril-parser vuln suspected), audio-safe (PCM loopback direct host path, Android effects bypassed — used when proxy parser suspect), netd-safe (container egress fully blocked except OTA-update host path — used on active-exfil suspicion; user sees "Network protection active" with reason + ETA), composer-safe (Android windows frozen to last frame + input held — used on fence-storm). Safe-mode entry: single `halide-<x>-bridge --safe-mode --reason <IR-id>` (journal + user banner both fire — silent safe-mode is a trust violation), exit: explicit `--recover` after fix verified (no auto-recover flapping — recovery without verification re-opens the hole). Quarterly safe-mode drill per bridge (IR §4 live-fire uses these; drill log proves the switch works before an attacker tests it).

## 17. Telemetry privacy architecture (opt-in means provably-off-by-default)

Data classes (enumerated in Settings → Privacy → Diagnostics with independent toggles, not one blanket): crash reports (tombstone + ramoops slice), usage counts (feature counters, no content), power telemetry (anonymized residency histograms), update checks (version ping only). Default all-OFF (firstboot §1.7 explicit opt-in; skip = declined — enforced in code review: any new telemetry call-site must name its toggle or the MR fails). Off-means-off proof: `tests/telemetry-off.sh` captures 10 min post-boot traffic on a declined device → allowlist (NTP + connectivity-check + user-initiated) vs observed — any non-allowlisted egress fails CI (the test runs per release on hardware, not just VIRT — VIRT lacks modem/SUPL paths that phone home in stock stacks; our SUPL/AGPS endpoints enumerated in the allowlist with purpose notes). On-means-minimal: crash bundles redacted by log-collect rules (support-log-script §1), counters aggregated with 24h jitter (no per-hour behavior fingerprinting), power histograms binned (no per-app timelines leave the device — dogfood analysts get bins, not biographies). Telemetry code lives in one auditable daemon (`halide-telemetryd`, own AppArmor profile ch.08 §10 + seccomp — exfiltration-shaped bug in the telemetry daemon is the nightmare; minimal parser + no raw-socket capability + egress-proxy-only networking contains it). Annual telemetry audit: third-party or rotating-internal reviewer diffs actual egress vs this section (published summary — "we collect X, here's the proof" page users can link).

## 18. systemd unit dependency debugging guide (the graph is load-bearing — debug it like code)

Map-first rule: before touching any unit, render the graph (`systemd-analyze critical-chain halide-android.service` + `systemd-analyze plot > /tmp/plot.svg` + `systemctl list-dependencies halide-android.service --all`). The §2 ASCII graph is the design; the `plot.svg` is the truth — divergence filed as a bug (usually a stray `Wants=` from a package hook §8 `20-units.sh` failed to mask).

Common failure patterns with exact commands. (a) Container waits forever on device units (`dev-binder.device` timeout): `systemctl show -p ActiveState,SubState,Result dev-binder.device` + `udevadm info -q all -n /dev/binder` (rule missing?) + `journalctl -u systemd-udevd -b` (rule error line) — fix is a udev rule + `udevadm control --reload`, never `Requires=` removal (removal boots a container without binder = §4 `BINDER_SET_CONTEXT_MGR` failure ch.03 §10). (b) Bridge starts before container ready (prop-bridge polls empty): check `After=halide-android.service` + `BindsTo=` vs `Wants=` (bridges that must die with the container use `BindsTo=` + `Restart=on-failure`; bridges that cache last-known state use `Wants=` + documented stale-banner — §7 drawer rule; wrong directive = phantom-green drawer). (c) Phosh before graphics (`phosh.service` crash-loops on missing `card0`): `systemctl show phosh.service -p After,Requires` must include `dev-dri-card0.device`; VIRT vs HW difference (§10 VIRT `virtio-gpu` node name differs — unit uses `systemd.device` alias list, not a hardcoded `card0`, with per-target drop-ins). (d) `degraded` state mysteries: `systemctl is-system-running` → `degraded` → `systemctl --failed` (the one failed unit named) → `journalctl -u <unit> -b -p err` → `systemd-analyze verify <unit>` (typo'd directives caught here, not at 2 AM). (e) Timeout vs deadlock: `systemctl show <unit> -p TimeoutStartSec,TimeoutStopSec` (container start timeout ≥150s to cover §2 120s `boot_completed` + margin — shorter timeouts murder slow-but-healthy boots on cold flash).

Debug toolkit (on-device, no host needed): `halide-units` wrapper (runs the four map commands + `systemd-analyze blame | head -15` into one timestamped bundle for bug reports), `systemd-run --pty` one-shot probes (test a bridge `--self-test` §9 under the live cgroup without editing units), `udevadm monitor --udev` during replug drills (ch.04 §21 USB matrix). Eng-only: `systemd.log_level=debug` cmdline (never release — log spam drowns the power story; CI greps release cmdline per ch.03 §19 policy extended).

Change discipline: unit edits require `systemd-analyze verify` green + VIRT boot + HW sacrificial boot (one line in a unit file has bricked more phones than kernel patches — `After=` typos boot-loop identically). `20-units.sh` hook (§8) is the only place units get enabled/masked at image build; manual `systemctl enable` on a live device without hook update is lab-only (image rebuild must reproduce the state — `diff <(systemctl list-unit-files) expected-unit-files.txt` in CI catches drift).

## 19. Journal/log retention policy (logs are evidence — sized, rotated, redacted)

Classes + homes: (1) host journal (`/var/log/journal/`, persistent, `SystemMaxUse=300M` + `MaxFileSec=14day` — phone flash is not a datacenter; 300M cap enforced by `journald.conf` drop-in committed in repo, not hand-tuned), (2) container logcat ring (in-container `logd` 256KB×4 buffers + host-side `halide-logcat-snapshot` (captures `logcat -b all -d` at container-stop/crash into journal with `BRIDGE=android-crash` field §9 — crash logs land in the host journal automatically, never stranded in a dead container), (3) pstore/ramoops (ch.03 §9 — collected by `halide-early.service` §2 into `/var/lib/halide/pstore/<boot-id>/` before rotation), (4) bridge metrics (7-day ring in `/run/halide/*.metrics` snapshots to `/var/lib/halide/metrics/` hourly — feeds power/jank dashboards, then aged out), (5) audit/SELinux (`audit.log` 50M ring + per-release baseline `logs/<sku>-selinux-baseline.txt` kept forever per ch.04 §14).

Retention table (documented in Settings → Privacy → Diagnostics alongside §17 toggles — users see what lives how long): journal 14d/300M, crash snapshots 30d (or 20 crashes, whichever first), pstore collections 10 boots, metrics 7d, audit ring 50M, backup manifests (§12) until next backup. Factory reset wipes all (§12 two-confirmation path — no log survives reset except the wipe-attestation line, by design). Diagnostics-export (`halide-log-export`, the one-tap button §2 crash policy): builds a redacted tarball (redaction rules file `logs/REDACT.rules`: IMEI/IMSI/MSISDN/phone-numbers/email/coordinates/BSSID patterns → `<redacted:class>`; export aborts if redaction tool missing — never ships raw), includes manifest (build ID, unit role, journal slice, crash snapshot, `plot.svg`, unit states, SOCKETS audit diff) — support roleplay (§18 launch list) practices reading exactly this bundle.

Full-disk pressure: `halide-storage-guard` timer (checks `/var` ≥500M free; at threshold: oldest journal vacuum + metrics purge + user banner "Storage low — logs trimmed, photos untouched" — logs die before user data, always, in that order). CI test: fill-`/var`-to-95% harness (log pipeline must not crash PID1 or the container — `NoSpaceLeft` paths return structured errors per SOCKETS backpressure rule §10).

## 20. User/group/permission model detail (every boundary has a name and a number)

Principals table (committed as `debian/users-groups.csv` — the hook §8 `10-hostname-user.sh` implements this file, CI diffs `getent` output against it on VIRT+HWDOG): `root` (0, no login, locked pw), `halide` (1000, human owner, groups `netdev,bluetooth,audio,video,render,plugdev,halide-bridges,dialout`), `halide-bridges` (system group, bridge daemons run as `halide-<bridge>:halide-bridges` via `DynamicUser=` + `SupplementaryGroups=` — compromise of one bridge doesn't read another's socket unless SOCKETS.md §10 says so), `halide-telemetryd` (own user + AppArmor §17 — minimal capability set: `CAP_SYSLOG` read-only + egress-proxy only), container idmap (`u/g 0 100000 65536` ch.04 §15 — host `halide` 1000 never collides with container AIDs; cross-boundary files use idmapped mounts + ACLs, documented per-share in SOCKETS.md threat notes).

Sudo/polkit: `halide` in `sudo` only on eng/dev images (release: no passwordless sudo — admin actions go through polkit prompts with per-action IDs `org.halide.{ota,backup,drawer-admin,log-export}`; polkit rules file reviewed like sepolicy (ch.04 §14 discipline adapted: each rule carries `WHY:` + expiry-or-`PERMANENT:` justification). `pkexec` fallbacks banned (polkit dialogs only — `pkexec` env-passing is the classic privesc shaped hole). Android-side root: absent (no `su` in release container; `adb root` refused — eng images only with banner; `lunch eng` guard ch.04 §16 covers the build side, this covers the runtime side).

File-boundary matrix (`bridges/BOUNDARIES.md`, audited with SOCKETS.md §10 by `scripts/socket-audit.sh` extended to paths): `/run/halide/*` (bridge sockets `0660 root:halide-bridges` + `SO_PEERCRED` allowlists), `/dev/binderfs` + `/dev/dri` (container bind per ch.04 §15 device allowlist — no direct `/dev/snd` (audio-bridge §4 proxy-only rule enforced by absence, verified by `ls /dev/snd` inside container = ENOENT test in contract suite), `/home/halide` (0700, container never mounted — share-bridge FD-passing §9 is the only file path, no bind-mount of home), `/data/android` (container rootfs backing, host-side backup reader only during `halide-backup` §12 with read-only bind + audit line), persist/EFS/calibration partitions (host-only, container `neverallow` ch.04 §14 — read requests via health/GNSS shims, never direct).

Review rule: any MR adding a user, group, socket, mount, or polkit rule updates all three (`users-groups.csv` + SOCKETS.md/BOUNDARIES.md + threat note) or CI `boundary-check` fails. Annual permission audit (with telemetry audit §17 — same reviewer rotation): live-device `getent` + `ss -x` + `mount` + `idmap` dumps diffed against the three files; drift explained or reverted.

## 21. Background-task budget (idle phones sip — every wake has a budget line)

Budget table (`power/BG-BUDGET.md`, per-SKU numbers after first calibration ch.10 §8): overnight (8h, screen-off, SIM+Wi-Fi on, no user apps foreground) total ≤X% battery (X from envelope ch.02 §6 — e.g., 8% on 3300mAh REF-A class; X pinned per SKU, not copied); per-class sub-budgets (Android sync/poll slice, host timers slice, modem paging slice, GNSS SUPL slice, telemetry slice when opted-in §17). Every periodic unit/timer carries a `BUDGET:` comment (rate + expected wake cost + owner): `halide-android-health` 30s poll (event-driven where possible — poll interval justified in comment with wakeup-source trace reference), metrics snapshot hourly, `fstrim` weekly (not daily — flash-wear + wake reasoning recorded), NTP/sync per OS default with metered-connection inhibition (NM meter flag §15 reused — no bulk sync on metered LTE without user opt-in).

Enforcement: `halide-power top` (§7 NFR dashboard) shows per-bridge/per-timer wake counts + suspend-residency (residency >90% overnight DoD §7 — dashboard reads from `wakeup_sources` + journal timer-start lines, one implementation both stacks trust). Regression rule: any MR adding a timer/shortening an interval attaches a before/after overnight estimate (or 2-night measurement on sacrificial for >5-min-interval changes — estimates allowed for rare timers, measurements required for frequent ones). Wakeup-storm guard: `halide-wake-guard` (alerts when any source exceeds 100/hr overnight — ch.03 §8 `qcom-step-wifi`-storm pattern generalized; alert fires to journal + dogfood channel with the offender named).

Doze/standby mapping (documented, not dual-managed): Android Doze/App-standby policies slaved to host suspend (host decides sleep; container receives `onPause` hints §6-composer + §8-display rule — Android never holds the AP awake past host suspend; `dumpsys deviceidle` state cross-checked against host `mem_sleep` in contract tests). Push without GMS (§12 position): host-side pollers replace FCM per-app (poll intervals in budget table with battery-impact notes shown in Settings — "hourly poll ≈ Y%/night" honesty from §22 competitor-rules applied to ourselves).

## 22. First-boot wizard data contract (EL0 MCC → locale/timezone without phoning home)

Inputs (in priority order): user explicit pick (always wins, recorded as `user-selected`), EL0 MCC from SIM (offline table `firstboot/mcc-locale.csv`: MCC → default locale/timezone/currency-format — table versioned, updated semi-annually from public MCC lists with diff committed), GNSS coarse fix (only if user enables location during setup — never auto-fix for locale; the privacy cost exceeds the convenience), IP geolocation (never — no network call during first-boot; the absence is a feature stated in the wizard footnote "we didn't ask the network where you are"). Outputs written atomically (all-or-nothing + journal line): host `localectl`/`timedatectl` (timezone + NTP on), `persist.sys.locale` + `persist.sys.timezone` via prop-allowlist (§9 — the ≤5s follow test runs during first-boot self-check), keyboard layout default from locale (CJK IME dormant per ch.01 §14 — enabled only on explicit user toggle).

Offline-table hygiene: unknown-MCC path (travel SIM, MVNO weirdness) falls back to `en-US` + UTC + explicit "check these" highlight (never guess from IMSI beyond MCC — MNC-to-carrier guessing misfires on roamers and the misfire ships as a wrong timezone; the fallback banner is honest). Test matrix (`tests/firstboot-locale.sh` on VIRT + one HW run per release): 12 locales from ch.01 §14 (each: MCC-in → expected locale/tz out, RTL smoke screenshot-diff per §16 NFR methods, Android locale follows host assertion), unknown-MCC fallback, user-override-wins (MCC suggests fr-FR, user picks de-DE → de-DE everywhere including container after reboot). Firstboot timing budget: wizard complete-to-Phosh ≤6 min (§18 launch list — measured on sacrificial with stopwatch log, not estimated).

## 23. Settings search federation (one search box — ch.01 §9 enforced in code)

Index construction: host GNOME Settings panels (schema IDs + keywords from `.desktop` `Keywords=` + panel names in all top-12 locales — untranslated keywords fall back to English with `UNTRANSLATED` metric so §16 l10n counts stay honest) + Android Settings intents allowlist (`settings/ANDROID-INTENTS.csv`: intent URI → host panel or bridge activity → fallback "opens Android Settings page" with robot badge — every row tested by `tests/settings-search.sh` which fires the intent and asserts the foreground surface). Ranking: exact panel-name match > keyword > Android-bridged (bridged results render with badge + "Android" subtitle — no masquerading; a test asserts the badge DOM/node presence so a theme change can't silently drop it). No-result path: structured empty state ("No setting found — try …" + 3 nearest matches by trigram, never a bare blank; zero-result query log sampled for missing-synonym additions quarterly with privacy review — query text stays on-device, only aggregated synonym candidates leave with opt-in telemetry §17).

Review gate (the teeth behind "one search"): any MR adding a second search entry point (new settings app, separate Android finder, per-bridge config UI with its own search) fails review citing this section + ch.01 §9 (alternatives: extend the federated index + intent row). Performance budget: keystroke→results ≤200ms p95 on REF-A (measured in `settings-search-perf.log` — 200 queries, cold + warm; index rebuild on package install/uninstall ≤2s with drawer shim generation §11 batched in the same transaction so search never lists uninstalled apps).

## 24. Time/NTP discipline (one clock, both stacks, no fights)

Ownership: host `systemd-timesyncd` (or chrony per footprint decision with numbers — same discipline as Epiphany/Firefox choice §15) is the single time authority; Android `auto-time` slaved via prop-bridge allowlist (§9 — `persist.sys.timezone` + `auto_time` value mirrored, conflict rule host-wins restated here so time bugs have one owner). NTP endpoints: distribution default + fallback enumerated in the telemetry-allowlist (§17 `tests/telemetry-off.sh` — NTP is allowlisted egress with purpose note; adding a pool without updating the allowlist fails CI). Metered-connection behavior: NTP sync deferred on metered LTE until unmetered or 24h elapsed (battery + data honesty §15/§21 — clock accuracy vs data-cost tradeoff documented, not silent). Leap-second/DST: exercised in `tests/time-jump.sh` (forward/backward 25h jump on VIRT + HW sacrificial: journal monotonicity asserted, container `boot_completed` retained, alarm/clock apps re-fire — DST bugs found here, not by dogfood users missing flights).

Rtc hardware: `RTC_DRV_PM8XXX` (ch.03 §3 config) drift measured (24h offline drift log per SKU in `hw/<sku>/rtc-drift.md` — >2s/day flags a hardware ticket; alarm-wake from power-off tested quarterly with stopwatch, result committed). Debug rule: time-jump testing never runs on dogfood units (alarms + OTP windows + certificate validity all break — sacrificial/VIRT only, traveler role check §17 ch.02 enforced by the test script reading the role file and refusing dogfood IDs).

## 25. cgroup resource policy per unit (unified v2 hierarchy, binding limits)

Slice layout (cgroup v2 unified, systemd-as-PID1 owns the tree — this restates the PID1 decision as a resource decision, never a second manager): `system.slice` (host daemons) + `halide.slice` (container + bridges + composer, `Slice=halide.slice` on every `halide-*` unit) + `app.slice` (user Flatpak apps) + `android.slice` inside the container (LXC `lxc.cgroup2.*` delegation, host sets the outer budget, Android LMK/`lmkd` manages only within it — host limit always wins on conflict). `systemd-oomd` manages host userspace pressure (`ManagedOOMPreference=avoid` on PID1/udevd/journald, `omit` on nothing — everything is killable except PID1 itself); container OOM preference is `avoid` at the outer cgroup (kill inside first via `lmkd`, breach the outer only on runaway) so a runaway Android game kills the game, never Phosh or Calls.

Binding per-unit table (`systemd/resource-limits.conf` drop-ins committed; `systemd-analyze verify` + `scripts/cgroup-audit.sh` assert live `systemctl show -p MemoryMax,TasksMax,CPUWeight` matches — drift fails CI):

| Unit | CPUWeight / CPUQuota | MemoryHigh / MemoryMax | TasksMax | OOMScoreAdjust / OOM pref | Breach behavior |
|---|---|---|---|---|---|
| `halide-android.service` (whole container outer) | Weight 400, no quota (burstable, never starved) | High 75% RAM, Max 85% RAM | 800 | OOM pref `avoid` (outer); inner `lmkd` kills cached apps first | Inner kills first; outer breach → `lxc-stop --kill` + §2 banner, host stays up |
| `halide-composer` / `phosh.service` | Weight 800 (foreground interactive) | High 400M, Max 600M | 150 | Score −200 (last to kill) | Breach → restart unit, preserve session; 3×/hour → degraded banner, not reboot |
| `halide-audio-bridge` | Weight 700 + `AllowedCPUs` inherit + RT `Nice=-10` (no RT FIFO v1 — latency via weight, not realtime) | High 150M, Max 250M | 60 | Score −100 | Breach → audio-safe mode (ch.05 §16) + underrun metric, never kill mid-call without duck-fade |
| `halide-ril-bridge` / `halide-netd-bridge` | Weight 600 | High 120M each, Max 200M each | 60 each | Score −100 | Breach → safe-mode (§16 ril-safe/netd-safe) + queue (§15 modem ladder), never drop queued SMS silently |
| `halide-prop-bridge`, notification, clipboard/share | Weight 200 | High 80M, Max 120M | 40 | Score 0 | Breach → restart + stale-banner (§7 drawer rule), metrics `RESTART` |
| `halide-telemetryd` | Weight 100, `CPUQuota=10%` (telemetry never steals frames) | High 60M, Max 100M | 30 | Score +200 (first to kill under pressure) | Breach → killed + `TELEMETRY_OOM` metric; no retry for 1h (backoff, not spin) |
| `halide-backup` / `halide-ota-*` (transient) | Weight 300, `IOWeight=200` (bulk, background) | High 300M, Max 500M | 100 | Score 0, `ManagedOOMPreference=kill` allowed | Breach → abort transaction + rollback (§12 invariant), user-visible "retry on Wi-Fi/charger" |

PIDs containment: every bridge `TasksMax` above is a fork-bomb fuse (compromised parser can't fork its way out — `execve` already denied per ch.08 §10 seccomp; `TasksMax` is the second net). Container `TasksMax=800` sized from `ps -e | wc -l` peak on REF-A + 30% headroom (number committed per SKU in `power/BG-BUDGET.md` companion file `systemd/<sku>-cgroup.md` — copying REF numbers to a 2GB SKU is a review fail).

Pressure observability: `halide-power top` (§21 dashboard) reads `memory.pressure` + `cpu.pressure` per slice (PSI, 10s/60s/300s windows) alongside wake counts — one screen shows "who ate RAM, who spun CPU, who woke the phone." Regression rule extends §21: any MR raising a `MemoryMax` or weight attaches a before/after `systemd-run --pty` + overnight-residency note. Test `tests/cgroup-pressure.sh`: synthetic hog in container (allocate to High) → assert inner `lmkd` kills precede any outer kill + host Calls still rings (foreground protection proven, not assumed).

## 26. Shutdown/reboot sequencing with container drain (order is a contract, not luck)

Shutdown target chain (systemd native, no custom init scripts): `reboot.target`/`poweroff.target` → `halide-drain.service` (`Before=halide-android.service halide-*-bridge.service`, `DefaultDependencies=no`, `TimeoutStopSec=45s`) → container stop → bridge stop → modem detach → filesystem sync → kernel. `halide-drain.service` is `Type=oneshot`, `RemainAfterExit=yes` on boot (so `systemctl stop` ordering applies at shutdown automatically); its `ExecStop=` runs the drain script. Removing its `Before=` without Arch sign is a release-blocker (shutdown-order edits get the same discipline as §18 unit edits: `verify` green + VIRT + HW sacrificial power-cycle ×20).

Drain steps (ordered, each with deadline so a hung Android app can't hold power-off hostage):
1. T+0s: broadcast `PrepareForShutdown(true)` on `org.halide.Android` + Android `ACTION_SHUTDOWN` (apps get 5s to flush; Chats/SMS send-queue fsync + bridge DB checkpoint §12 snapshot path reused — same code, not a second implementation).
2. T+5s: freeze new MO dials/SMS submits (reuse §15 modem-ladder "Radio restarting" queue copy: "Shutting down" variant — user sees truth, not a spinner).
3. T+5–20s: `lxc-stop -n android -t 15` (graceful SIGPWR → SIGTERM → SIGKILL escalation inside; 15s budget, then SIGKILL — a wedged container delays shutdown by 15s max, never indefinitely; wedged-shutdown metric `DRAIN_KILL9` distinguishes clean vs forced for the power dashboard).
4. T+20–30s: modem detach via MM (`--modem-disable` + bearer down — clean deregister beats abrupt RF drop for carrier-signalling hygiene; emergency-callback-mode respected: if within 30 min of an emergency call, drain waits for callback window expiry or explicit user override — regulatory rule, tested with fixture).
5. T+30–40s: unmount idmapped container binds + LUKS volume sync (`sync` + journal commit; no crypto-erase here — factory-reset path §12 is separate and requires its own confirms, never reachable from a plain power-off).
6. T+40s: `journalctl --flush` + pstore marker (`SHUTDOWN-CLEAN <boot-id>`) so the next boot distinguishes clean-off from crash (ch.03 §9 ramoops triage reads this marker first).

Reboot vs poweroff vs factory-reset vs OTA-reboot (four paths, one drain core): plain reboot/poweroff run the full drain; OTA-reboot (ch.09) runs drain + `halide-ota-pre` snapshot (§12) before step 4 (snapshot-then-detach order — snapshotting after modem-down races registration state); factory-reset reboots into recovery, never through this drain (recovery owns erase per ch.08 §21 — stating the non-path prevents a future "fast reset" shortcut from skipping verify). Emergency long-press (10s power hold): hardware PMIC cutoff bypasses drain by design (last-resort hang escape); next boot runs `halide-dirty-boot.service` (fsck + bridge-DB integrity check + "unexpected shutdown" journal tag — abrupt-cutoff boots are diagnosed, not silently forgiven).

Power-button UX contract: short-press → suspend (host decides sleep, §21 Doze mapping); 1s hold → power menu (Restart / Power off / Emergency / Screenshot — Android power menu suppressed, single menu rule mirrors §23 single-search rule); 10s hold → forced cutoff (documented in user guide as "unsaved texts may be lost" honesty). Test matrix `tests/shutdown-drain.sh` (VIRT + HW): 20 clean poweroffs (assert `SHUTDOWN-CLEAN` + SMS-count preserved §12 tolerance), 20 reboots (assert attach ≤90s post-boot per ch.07 §6 — drain must not slow boot), 5 forced cutoffs (assert dirty-boot check runs + no bridge-DB corruption), 3 OTA-reboots (assert snapshot counts + post-OTA recount green).

## 27. Locale/timezone runtime propagation contract (companion to §22 first-boot — runtime, not setup)

§22 decides first-boot defaults from MCC without phoning home; this section owns every change after that (user pick, travel, DST) with one rule: host `localectl`/`timedatectl` is the single writer, prop-bridge is the single messenger, Android never self-sets. Change paths: Settings → Region/Language (host panel, federated search §23 row) writes `localectl set-locale` + `timedatectl set-timezone` → `halide-locale-notify.service` (path-activated on `/etc/locale.conf` + `timedatectl` property change) validates against `firstboot/mcc-locale.csv` locale list + top-12 translation coverage (§16 NFR) → prop-bridge allowlist write (`persist.sys.locale`, `persist.sys.timezone` only — §9 list restated here so locale bugs have one owner) → container `ActivityManager` broadcast + host apps `LC_*` re-exec (Phosh shell reloads `gettext` domain without logout; Flatpak apps receive portal `SettingsChanged` — logout-required locale changes are a v1 bug, not a limitation).

Conflict matrix (host-wins, logged, never silent): Android app calls `setTimeZone` API → bridge rejects with `org.halide.Error.Denied` + journal `LOCALE_CONFLICT` line (§9 audit pattern); NITZ-from-modem timezone (ch.07 NITZ source) vs user-manual pick → manual wins until user re-enables "Automatic" (toggle state stored host-side, mirrored read-only to Android `auto_time` — the mirror direction is the contract); travel-Roaming new-MCC (§16 prompt) suggests but never applies a timezone change (suggestion banner with one-tap apply — auto-changing timezone on border-cell flap is the §16 hysteresis bug in locale clothing). DST/suspend interplay: timezone database (`tzdata`) version pinned in manifest (§8 snapshot discipline extended — `tzdata` bump is a release-notes line; stale-tzdata missed-flight bugs are support tickets with dates); suspend across a DST boundary re-fires alarms via §29 vote path (test `time-jump` + drain-shutdown combined: set clock T-5min pre-transition, suspend, resume post-transition, assert both host Calendar and Android Clock alarms fire ≤60s).

Env/ICU detail: host `LANG/LC_TIME/LC_NUMERIC` from `locale.conf` (UTF-8 enforced — non-UTF8 locale is a build fail); container `persist.sys.locale` BCP-47 (`fr-FR` ↔ `fr_FR.UTF-8` mapping table `firstboot/locale-map.csv`, tested for all 12 §14 locales + unknown-fallback `en-US` path from §22); CJK IME dormancy (§22) persists across runtime locale switches (switching to `ja-JP` suggests — never auto-enables — the IME with the §22 privacy note). Verification `tests/locale-runtime.sh`: 12-locale switch matrix (host pick → Android `getprop` follows ≤5s assertion from §4, reversed: Android-side request → denied + logged), RTL smoke per §16 methods, reboot-persistence (locale survives drain-reboot §26), travel-suggestion (roaming fixture → suggest, not apply).

## 28. Settings-search federation daemon internals & ranking implementation (companion to §23 design)

§23 states the one-search-box rule and ranking order; this section is the buildable daemon contract (`halide-settings-index`, host service in `halide.slice`, Weight 200 / Max 120M per §25 — search never OOMs Calls). Index build (single transaction with drawer shim generation §11 — same transaction, so search never lists uninstalled apps): inputs (1) host panels (parsed from `/usr/share/applications/*settings*.desktop` `Name/Keywords` in all top-12 locales + gsettings schema IDs, untranslated → English fallback + `UNTRANSLATED` metric per §23), (2) Android intents (`settings/ANDROID-INTENTS.csv`: `intent_uri,host_panel_or_bridge_activity,fallback_label,badge_required` — every row fired by `tests/settings-search.sh` asserting foreground surface + robot-badge node presence), (3) bridge toggles (VPN kill-switch, roaming budget, hotspot PSK rotation — each exposes `SearchKeywords` in its D-Bus introspection so toggles are searchable without a second config UI). Index file (`~/.cache/halide/settings-index.json`, versioned schema `index_version: 3`): trigram posting lists + per-entry `source{host|android}`, `panel_id`, `keywords[]`, `locale`, `action{dbus|intent}` — rebuild ≤2s on install/uninstall (§23 budget) via inotify on desktop dirs + `pm` watcher, atomic rename (readers never see half-index).

Ranking implementation (deterministic, debuggable — `halide-settings-index --explain <query>` prints score breakdown for bug reports): exact localized panel-name match (100) > English-name match (80) > keyword prefix (60) > trigram fuzzy (40, threshold ≥0.55) > Android-bridged (capped 50 even on exact — bridged never outranks native, §23 masquerading rule in arithmetic); recency boost (+5 if launched in last 7d, stored locally, never leaves device per §17); zero-result path returns 3 nearest by trigram + logs anonymized miss-counter (on-device aggregation only — query text leaves only under opt-in §17). Perf contract: keystroke→results ≤200ms p95 REF-A (`settings-search-perf.log`: 200 queries cold+warm, CI gate); index-corruption fallback (parse fail → rebuild synchronously with "updating…" row, never empty screen). Review teeth restated as code: `scripts/search-gate.sh` greps new `.desktop`/`SettingsActivity` additions without index rows and fails the MR (the §23 "second search box is a review fail" rule, automated).

## 29. Time-source voting, monotonic discipline & jump handling (companion to §24 — the algorithm §24 defers to)

§24 names host `timesyncd`/`chrony` the single authority and Android `auto-time` the slave; this section specifies the vote when sources disagree (NTP vs NITZ-from-modem vs GNSS vs user-manual) plus the monotonic guarantees both stacks rely on. Sources and trust: (1) user-manual (highest when "Automatic" off — explicit human wins; stored with timestamp so stale-manual older than 30d warns "check date/time" on TLS failures instead of cryptic browser errors), (2) NTP (default when Automatic on — endpoints allowlisted per §17/§24; stratum + root-dispersion recorded per sync in journal `TIME_SYNC` line), (3) NITZ from modem (MM `ModemTime` signal via ril-bridge — trusted for timezone-hint + coarse sanity, never steps the clock more than ±5 min without NTP corroboration; NITZ-spoofing base-station threat row lives in ch.08 supply-chain table), (4) GNSS (lowest weight for wall-clock — position-time aids SUPL acquisition but 1s-class GNSS time never overrides NTP; GNSS-week-rollover tested per SKU with fixture). Vote algorithm (`halide-time-vote`, runs in `halide-locale-notify.service` context on every source event): if manual → apply manual + mark `TIME_HOLD_MANUAL` (NTP/NITZ/GNSS logged-only); else if NTP fresh (≤24h, dispersion ≤1s) → NTP wins, NITZ/GNSS corroborate (divergence >5 min → `TIME_DIVERGE` alert + telemetry counter when opted-in, never silent step); else if NTP stale + NITZ fresh → NITZ steps clock with `TIME_SOURCE=NITZ` journal tag + re-sync NTP ASAP (metered-defer rule §24 respected — data-cost honesty outranks sub-minute accuracy); else hold last-known + `CLOCK_HOLDOVER` banner in Settings → Date & Time (offline >24h path from §24 rtc-drift file, per-SKU drift numbers shown so "why is my clock off" has an answer).

Monotonic/jump guarantees (both stacks break on backward jumps — alarms, OTP, certificates, `boot_completed`): forward jumps apply immediately + broadcast (`TIME_SET` to container, alarm re-arm asserted); backward jumps >60s require the §26 drain-quiesce (no backward step while container running — stop-container → step → restart-container, reusing drain escalation so DST-test bugs can't corrupt Chats timestamps); `CLOCK_MONOTONIC` never steps (kernel guarantee relied upon by §21 residency math — `halide-power top` uses monotonic deltas, wall-clock never enters battery accounting). RTC validation at power-on (`RTC_DRV_PM8XXX` §24): if RTC reads pre-2026 or post-2040 → `RTC_SUSPECT` (ignore RTC, holdover + NTP ASAP, log — dead-coin-cell boots with year-2000 TLS-everything-broken get a diagnosis, not a mystery); alarm-wake-from-power-off quarterly test (§24) runs through this voter (alarm fires on RTC match even in holdover — alarm path never waits for NTP). Verification `tests/time-vote.sh` (sacrificial/VIRT only per §24 debug rule — refuses dogfood IDs): NITZ-vs-NTP diverge fixture (assert NTP wins + alert), 25h forward/backward jumps (assert forward-live + backward-drain + `boot_completed` retained + alarms re-fire), RTC_SUSPECT fixture (assert holdover + banner), airplane-offline 24h drift (assert per-SKU drift file bounds).

## 30. LXC AppArmor/seccomp profile set (per-mount rules, pivot-root policy, denial triage)

Container confinement is mandatory access control, not defense-in-depth decoration: the Android container runs as host-root-owned LXC (required for binder/mount setup) so AppArmor + seccomp-bpf are the boundary that keeps a container-root exploit from becoming a host-root exploit. Profiles live in `lxc/apparmor/` + `lxc/seccomp/` in-repo, installed by hook §8 `20-units.sh` to `/etc/apparmor.d/lxc-android` + `/var/lib/lxc/android/seccomp.policy`; CI asserts byte-identity (`diff <(apparmor_parser --dump lxc-android) live-dump`) so a hand-edit on a lab device without repo update fails `boundary-check` exactly like §20 drift.

AppArmor profile `lxc-android` (excerpt, full file ~180 lines — every mount, device, socket enumerated, no `/** rw` wildcards):

```
profile lxc-android flags=(attach_disconnected,mediate_deleted) {
  # pivot-root policy: new root is the container rootfs, old root unmounted, no re-entry
  pivot_root oldroot=/mnt/oldroot/,
  deny remount /mnt/oldroot/**,
  deny mount -> /mnt/oldroot/**,
  umount /mnt/oldroot/,

  # per-mount rules: allowlist only, matching ch.04 §15 device/mount allowlist
  mount fstype=binderfs -> /dev/binderfs/,
  mount fstype=tmpfs -> /dev/**,
  mount options=(ro,bind) /vendor/ -> /vendor/,
  mount options=(ro,bind) /system/ -> /system/,
  deny mount fstype=debugfs,
  deny mount fstype=tracefs -> /**,
  deny mount fstype=configfs -> /**,
  deny mount -> /home/**,
  deny mount -> /data/host/**,
  deny remount /sys/** w,

  # devices: binder + dri + qrtr proxied, never snd/mmcblk/EFS
  /dev/binderfs/** rw,
  /dev/dri/card0 r,
  /dev/dri/renderD128 rw,
  /dev/qrtr-ns w,
  deny /dev/snd/** rwklx,
  deny /dev/mmcblk* rwklx,
  deny /dev/block/bootdevice/by-name/persist* rwklx,
  deny /dev/block/bootdevice/by-name/modemst* rwklx,

  # bridge sockets only (§10 SOCKETS.md paths), no abstract-socket escape
  /run/halide/audio-proxy rw,
  /run/halide/netd-proxy rw,
  /run/halide/ril-proxy rw,
  /run/halide/prop-proxy rw,
  deny network raw,
  deny network packet,
  deny capability sys_rawio,
  deny capability sys_module,
  deny capability sys_admin,
  capability net_bind_service,
  capability setgid, setuid,

  # ptrace/perf: container cannot inspect host or sibling
  deny ptrace peer=unconfined,
  deny signal peer=unconfined,
  deny /proc/sys/** w,
  deny /sys/kernel/debug/** rwklx,
}
```

LXC config pins (`/var/lib/lxc/android/config`, generated from `lxc/android.conf.in` — never hand-edited on device):

```
lxc.apparmor.profile = lxc-android
lxc.seccomp.profile = /var/lib/lxc/android/seccomp.policy
lxc.rootfs.path = dir:/data/android/rootfs
lxc.mount.entry = /dev/binderfs dev/binderfs none bind,create=dir 0 0
lxc.mount.entry = /dev/dri dev/dri none bind,ro,create=dir 0 0
lxc.cgroup2.memory.high = 75%RAM
lxc.cgroup2.memory.max = 85%RAM
lxc.cgroup2.pids.max = 800
lxc.cap.drop = sys_module sys_rawio sys_boot sys_time mac_admin mac_override
lxc.cap.keep = net_bind_service setuid setgid
```

Seccomp policy (`seccomp.policy`, JSON allowlist ~90 syscalls — default-deny with `SCMP_ACT_TRAP` so violations land in audit with the offending nr, not silent EPERM): allowed `read/write/openat/close/mmap/mprotect/brk/futex/epoll_*/binder_thread_read-write-ioctl subset/clone3(narrowed flags)/...`; denied-hard `mount` (only init phase, blocked post-pivot via `lxc.seccomp` + AppArmor double-net), `ptrace`, `perf_event_open`, `bpf`, `init_module`, `finit_module`, `kexec_load`, `open_by_handle_at`, `userfaultfd`. `kexec/init_module` attempts are release-blocker signals (container trying to load kernel code = compromise-or-test-escape, either way IR §2 path).

Denial triage runbook (`scripts/aa-triage.sh`, on-device + CI log-scrubber): (1) reproduce under `auditd` (`auditctl -w /etc/apparmor.d/ -p wa`), (2) capture `ausearch -m AVC,SECCOMP -ts recent` slice, (3) classify allow-vs-bug (new legitimate path → profile MR with `WHY:` + contract-test evidence; exploit-shaped → IR containment §16 safe-mode + forensic snapshot). Canonical excerpts every engineer must recognize:

```
# legitimate-missing-rule shape (fix = narrow allow, not wildcard):
type=AVC msg=audit(1782001201.412:88): apparmor="DENIED" operation="open"
  profile="lxc-android" name="/dev/qrtr-ns" comm="rild" requested_mask="w" denied_mask="w"
  -> triage: qrtr-ns write missing after SKU port; add single line + ril-bridge
     contract re-run; wildcard /dev/** is a review fail.

# exploit-shaped shape (fix = contain, never allow):
type=AVC msg=audit(1782001310.003:91): apparmor="DENIED" operation="mount"
  profile="lxc-android" name="/mnt/oldroot/sys/" comm="exploit-test" fstype="sysfs"
  -> triage: pivot-root escape attempt; do NOT add rule; enter netd-safe +
     snapshot + IR ticket. Any MR adding oldroot mount allowance is auto-rejected.

type=SECCOMP msg=audit(1782001402.551:94): auid=100000 uid=100000 comm="payload"
  sig=31 syscall=319 arch=c00000b7 compat=0 ip=0x7f... code=0x50000 (TRAP)
  -> syscall 319 = bpf(2) on arm64; container bpf is never legitimate v1.
```

Expected outputs: `aa-status | grep lxc-android` shows `enforce` (never `complain` on release — complain is lab-only with 48h expiry tag); `scripts/aa-triage.sh --self-check` prints `PROFILE-OK mounts=14 devices=6 sockets=4 denials-baseline=0`; CI `boundary-check` diffs live `aa-status` + `ss -x` + `mount | grep android` against `lxc/apparmor/expected-*` (zero drift). Quarterly drill: fire the three fixture denials above on sacrificial, assert triage script classifies 1-allow/2-contain with zero human hint.

Complain-to-enforce promotion (new-SKU bringup only): new device boots lab image with `lxc-android-complain` flag (profile in complain mode, denials logged not blocked) for one full CTS + radio + camera pass; `aa-logprof` output reviewed line-by-line (each addition needs `WHY:` + exercised-code path — `rild qrtr-ns w` because `ril-bridge --self-test` fires it, not "might need"); wildcard proposals (`/dev/**`, `/sys/**`) auto-rejected by `scripts/profile-lint.sh`. Promotion MR must attach `tests/apparmor-seccomp.sh` green on HW: (1) `lxc-attach -n android -- ls /dev/snd` = ENOENT, (2) `lxc-attach -n android -- cat /sys/kernel/debug/tracing/trace` = DENIED + audit line, (3) `nsenter`-escape fixture blocked, (4) `bpf()` fixture TRAP + audit, (5) binder + dri + qrtr smoke passes (container still functional — confinement without function is brick). Seccomp arch note: policy ships both `aarch64` nr table (`bpf=319`, `perf_event_open=241`, `ptrace=117`) and `x86_64` VIRT table (`bpf=321`, `perf_event_open=298`) — `libseccomp` resolves by arch at load; `halide-seccomp-dump --check` prints both and CI asserts the denied set identical (VIRT gap that lets a syscall through which HW blocks is a test-escape hole).

Expected `tests/apparmor-seccomp.sh` tail (CI golden):

```
PASS snd-absent (ENOENT)
PASS debugfs-denied (AVC 1)
PASS oldroot-escape-denied (AVC 1)
PASS bpf-trap (SECCOMP 1, nr=319/321)
PASS qrtr-functional (rild hello OK)
RESULT 5/5 PROFILE-OK enforce
```

## 31. PipeWire↔AudioFlinger bridge latency/overrun runbook (node graph, pw-top, quantum tuning, xrun counters)

Audio correctness is latency + continuity: the host owns the ALSA device exclusively (§9 udev rule — container `ls /dev/snd` = ENOENT contract test), the `halide-audio-daemon` is the single PipeWire client bridging Android `audioserver` streams over `/run/halide/audio-proxy` (length-prefixed PCM frames, 48 kHz / S16LE / stereo v1 — format negotiation table in `audio/FORMATS.md`, anything else resampled host-side with the cost logged, never silently accepted at the wrong rate). Node graph (steady-state music playback + idle call path):

```
[Android AudioTrack] --PCM 48k--> [audioserver proxy shim] --socket /run/halide/audio-proxy-->
  [halide-audio-daemon:playback-node 44] --float32--> [PipeWire graph] --mix--> [alsa_output.platform-snd]
[Modem PCM DL] <---> [halide-audio-daemon:call-node 45 (ECHO-CANCEL role)] <---> [alsa_input/alsa_output voice pins]
[GNOME Calls ringtone] --> [PipeWire stream RINGING role] --duck -20dB media--> [same sink]
```

Daemon unit (`halide-audio-bridge.service`, §25 Weight 700 / Nice −10 excerpt):

```ini
[Unit]
Description=HALIDE PipeWire<->AudioFlinger bridge
After=pipewire.service wireplumber.service halide-android.service
BindsTo=halide-android.service
[Service]
Type=notify
User=halide-audio
SupplementaryGroups=halide-bridges audio
ExecStart=/usr/sbin/halide-audio-daemon --quantum 256 --rate 48000 --role-map /etc/halide/audio-roles.conf
Restart=on-failure
RestartSec=2s
Nice=-10
LimitRTPRIO=0
MemoryHigh=150M
MemoryMax=250M
TasksMax=60
[Install]
WantedBy=halide.slice
```

Quantum tuning table (`audio/<sku>/quantum.conf`, per-SKU measured — copying REF-A numbers to a new codec is a review fail):

| Path | Quantum | Rate | Headroom | Why |
|---|---|---|---|---|
| Media playback (speaker/BT A2DP) | 512 | 48 kHz | 2 quanta | BT jitter absorbs 10–20 ms; 512 = ~10.6 ms, lowest xrun rate in overnight soak |
| Voice call (modem PCM ↔ sink) | 256 | 16 kHz NB / 48 kHz WB path | 1 quantum + EC tail 40 ms | 256 NB = 16 ms mouth-to-ear budget; larger quantum adds perceptible talker-echo even with EC |
| Ringtone/duck event | preempt: drop to 256 for 3 s | 48 kHz | duck −20 dB, not cut (§9) | duck-fade 80 ms ramp; hard cut measured as click in `audio/click-scan.sh` |
| USB-C headset | 256 | 48 kHz | 2 quanta | USB async endpoint drift; daemon servo logs `drift_ppm` per minute |

Observability (the runbook commands, expected shapes committed as golden files): `pw-top` steady-state shows `ERR` column 0 on nodes 44/45 over 60 s (`tests/audio-xrun.sh` asserts: 5-min music + 2-min call + ringtone injection, `xrun_total == 0` on REF-A wired, `<=3` on BT A2DP with reasons `bt-jitter` tagged); `pw-dump | jq '.[] | select(.id==44) | .info.props'` shows `node.latency = 512/48000`, `audio.channels=2`, `media.role=Multimedia`; daemon metrics `/run/halide/audio.metrics` counters `playback_xrun_total`, `capture_xrun_total`, `quantum_switches_total`, `duck_events_total`, `socket_backpressure_drops_total` (drop-newest with 100 ms deadline per §10 — block-without-deadline is the §7 double-audio echo root cause, never reintroduced). Underrun vs overrun split: playback underrun (daemon starved PipeWire → gap/click; cause: container scheduler stall or socket backpressure) vs capture overrun (modem PCM arrived faster than EC consumed; cause: quantum too large on call path) — `halide-audio-daemon --explain-xrun <counter-snapshot>` prints the classification + the single knob to turn (quantum down vs headroom up vs `CPUWeight` check per §25), so 2 AM triage is one command, not a thesis.

Failure drills (quarterly, sacrificial): kill daemon mid-call → `BindsTo=` restarts ≤2 s + duck-fade re-applies + `RESTART` metric (never full-volume blast — restart-at-unity-gain is a safety bug filed P1); flood socket with 2× rate frames → backpressure drops counted + `pw-top ERR` stays 0 on the sink (graph isolated from container flood); BT disconnect mid-playback → node 44 reparents to speaker sink ≤1 s with `ROUTE_SWITCH` journal line. Expected outputs block (CI golden): `pw-top -b -n 60` excerpt with `ERR 0 0`, `cat /run/halide/audio.metrics` with all xrun counters at baseline, `journalctl -u halide-audio-bridge --since -10min | grep -c XRUN` = 0 on wired soak.

Soak harness `tests/audio-xrun.sh` (runs on HW sacrificial, VIRT smoke only — VIRT has no modem PCM timing truth):

```bash
#!/bin/sh -e
halide-audio-daemon --self-test --quantum 256 || exit 1
pw-top -b -n 300 > /tmp/pw-top.log 2>&1 &
pw-play --volume 0.2 /usr/share/sounds/freedesktop/stereo/music.oga &
AUDIOPID=$!
sleep 300; kill $AUDIOPID; wait $AUDIOPID || true
halide-call-fixture --duration 120 --inject-ring --duck-check >> /tmp/pw-top.log
awk '$NF!=0 {err++} END {print "xrun_lines=" err+0}' /tmp/pw-top.log
cat /run/halide/audio.metrics
```

Golden `pw-top -b` excerpt (committed `audio/pw-top-golden.txt`, CI normalizes node IDs then diffs `ERR` + `QUANT` columns only — rate jitter is hardware, error counts are contract):

```
R ID  QUANT  RATE   WAIT  BUSY   W/Q   B/Q  ERR FORMAT
R 44    512  48000  12us  340us 0.02  0.07   0 F32
R 45    256  16000   8us  210us 0.01  0.05   0 S16
R 51    512  48000   9us  180us 0.01  0.04   0 F32
```

`cat /run/halide/audio.metrics` golden tail: `playback_xrun_total 0`, `capture_xrun_total 0`, `quantum_switches_total 2` (media→call→media), `duck_events_total 1`, `drift_ppm +12`. WirePlumber rule (`/etc/wireplumber/main.lua.d/50-halide-roles.lua`): `Multimedia` duck on `RINGING/OFFHOOK`, `Voice` never ducked, `Notification` capped −6 dB over call (notification blast over an active call earpiece is the safety regression this rule exists to prevent — verified with SPL meter on REF-A, result in `audio/<sku>/spl-max.md`).

## 32. NetworkManager dispatcher scripts for Android netd shim (up/down hooks, DNS merge order, captive-portal single-owner rule)

Single-stack rule restated as code (§4 netd-bridge design becomes this section's implementation): NetworkManager is the only entity that touches interfaces, routes, DNS, and captive-portal login; Android `netd`/`ConnectivityService` is slaved through the `libnetd-halide` proxy + dispatcher hooks — any Android-side attempt to own the network is rejected with `PERMISSION_DENIED` + journal line + `HALIDE-BRIDGED` marker in `dumpsys connectivity`. Dispatcher entrypoint (`/etc/NetworkManager/dispatcher.d/90-halide-netd`, owned root:root 0755, in-repo source `net/dispatcher-90-halide.sh` — device diff fails `boundary-check`):

```bash
#!/bin/sh -e
# 90-halide-netd: NM -> Android netd shim. Args: <iface> <event>.
IFACE="$1"; EVENT="$2"
BRIDGE_SOCK="/run/halide/netd-proxy"
log() { logger -t halide-netd "iface=$IFACE event=$EVENT $1"; }

case "$EVENT" in
  pre-up)
    # veto Android-held routes before NM commits (prevents dual-default flap §7)
    /usr/sbin/halide-netd-bridge --freeze-android-routes --iface "$IFACE" || log "freeze-failed"
    ;;
  up)
    ADDRS="$(nmcli -g IP4.ADDRESS,IP6.ADDRESS con show --active "$CONNECTION_UUID" 2>/dev/null || true)"
    GW="$(nmcli -g IP4.GATEWAY,IP6.GATEWAY con show --active "$CONNECTION_UUID" 2>/dev/null || true)"
    METERED="$(nmcli -f GENERAL.METERED -t con show --active "$CONNECTION_UUID" 2>/dev/null | head -1)"
    /usr/sbin/halide-netd-bridge --push --iface "$IFACE" --addrs "$ADDRS" --gw "$GW" --metered "$METERED"
    /usr/sbin/halide-dns-merge --iface "$IFACE" --event up
    log "pushed addrs=$ADDRS metered=$METERED"
    ;;
  down|pre-down)
    /usr/sbin/halide-netd-bridge --withdraw --iface "$IFACE"
    /usr/sbin/halide-dns-merge --iface "$IFACE" --event down
    log "withdrawn"
    ;;
  vpn-up)
    # VPN owns default route both stacks (§4); slave Android to host TUN
    /usr/sbin/halide-netd-bridge --push-vpn --iface "$IFACE" --tun "$VPN_IP_IFACE"
    log "vpn-slaved tun=$VPN_IP_IFACE"
    ;;
  vpn-down)
    /usr/sbin/halide-netd-bridge --restore-default --iface "$IFACE"
    log "vpn-released"
    ;;
  connectivity-change)
    /usr/sbin/halide-portal-announce --iface "$IFACE" --state "$CONNECTIVITY_STATE"
    ;;
esac
exit 0
```

DNS merge order (`halide-dns-merge`, the file testers actually debug): single resolver = host `systemd-resolved`; Android DNS is forwarded, never a second cache (§9). Merge precedence: VPN-provided DNS > NM per-connection DNS > fallback (`9.9.9.9` only when no other, logged as `DNS_FALLBACK` — fallback without a log line is a privacy bug). Implementation: dispatcher writes NM servers into `resolvectl dns <iface> ...` + `resolvectl domain <iface> "~."` on the winning iface only, then pushes the flattened server list over the netd socket (`--push-dns 10.0.0.53#wlan0,1.1.1.1#vpn0`); container `getprop net.dns1` must equal the pushed first server ≤3 s (contract assertion `tests/netd-contract.sh: dns-follows`). `resolvectl status` golden excerpt (CI compares normalized output):

```
Link 3 (wlan0)
    Current Scopes: DNS
         Protocols: +DefaultRoute +LLMNR -mDNS
       DNS Servers: 192.168.1.1 9.9.9.9
        DNS Domain: ~.
Link 4 (rmnet_data0 via bridge)
    Current Scopes: none (slaved — no independent DNS)
```

Captive-portal single-owner rule (the dual-login war, ended by fiat): NM `connectivity-check` owns detection + login-window; Android `CaptivePortalLogin` activity is suppressed via bridge (`captive_portal_mode=0` overlay + intent intercept returning `ALREADY_HANDLED` with `HALIDE-BRIDGED` marker). Portal flow: NM `connectivity-change FULL→PORTAL` → `halide-portal-announce` broadcasts `org.halide.PortalState(PORTAL, ssid)` → Android shows bridged banner "Wi-Fi needs sign-in — Open" (opens host Epiphany portal page, never the Android WebView with its separate cookie jar); on `PORTAL→FULL`, bridge pushes `VALIDATED` and both stacks mark metered/unmetered identically. Two-login-windows-open is a P1 (credential entered twice = trust burn). Meteredness mirrors with the route push (`--metered yes|no|guess`): `dumpsys connectivity | grep -i metered` must match `nmcli -f GENERAL.METERED` within one poll (contract test fails on mismatch — big-download guards depend on it per §9).

Expected outputs: `nmcli general status` + `dumpsys connectivity | grep HALIDE-BRIDGED` both show the bridge marker on every active network; `tests/netd-contract.sh` matrix green (wifi-up → Android route appears ≤3 s; host-VPN-up → container `curl ifconfig.co` returns VPN IP §4 test; Android `ndc interface setcfg wlan0 down` → `PERMISSION_DENIED` + host route intact; portal fixture → exactly one login window; DNS switch → `getprop net.dns1` follows ≤3 s; airplane toggle → `rfkill` truth + recovery ≤60 s per §4 ril rule).

`halide-dns-merge` core (in-repo `net/halide-dns-merge.sh`, idempotent — dispatcher may fire `up` twice on roaming flap; second run is a no-op with `DNS_NOCHANGE` log, never duplicate `resolvectl` entries):

```bash
#!/bin/sh -e
IFACE=""; EVENT=""
while [ $# -gt 0 ]; do case "$1" in --iface) IFACE="$2"; shift 2;; --event) EVENT="$2"; shift 2;; *) shift;; esac; done
SERVERS="$(nmcli -g IP4.DNS,IP6.DNS con show --active 2>/dev/null | tr ',' ' ' | tr '|' ' ')"
[ -n "$SERVERS" ] || { SERVERS="9.9.9.9"; logger -t halide-dns "DNS_FALLBACK iface=$IFACE"; }
if [ "$EVENT" = "up" ]; then
  resolvectl dns "$IFACE" $SERVERS
  resolvectl domain "$IFACE" "~."
  resolvectl default-route "$IFACE" yes
  /usr/sbin/halide-netd-bridge --push-dns "$(echo $SERVERS | tr ' ' ',')#$IFACE"
else
  resolvectl revert "$IFACE" || true
  /usr/sbin/halide-netd-bridge --push-dns "9.9.9.9#fallback"
fi
```

Hotspot/tethering rule (second single-owner in this section): host Hotspot switch owns `wlan0` AP mode + DHCP + NAT; Android hotspot tile hidden v1 (same duplicate-UI doctrine as §11 dialer + §23 search — two hotspot switches double-NAT and the bug report is un-debuggable). Bridge exposes Android `TetheringManager` state read-only so third-party apps showing "hotspot on" still render correctly while the toggle intent returns `ALREADY_HANDLED`. `tests/netd-contract.sh` excerpt (each assert prints `PASS/FAIL <name>`; 0 FAIL gates release):

```bash
nmcli con up id halide-lab-wifi
sleep 3; dumpsys connectivity | grep -q HALIDE-BRIDGED || fail bridged-marker
[ "$(getprop net.dns1)" = "$(resolvectl -i wlan0 status | awk '/DNS Servers/{print $3}')" ] || fail dns-follows
ndc interface setcfg wlan0 down 2>&1 | grep -q PERMISSION_DENIED || fail android-down-rejected
halide-portal-fixture --portal | grep -c LOGIN_WINDOW | grep -qx 1 || fail single-portal-window
```

Dispatcher failure mode: hook exit non-zero never blocks NM (dispatcher scripts are advisory — `set -e` failures log + `DISPATCHER_FAIL` metric, connection still comes up; blocking Wi-Fi because a bridge socket hiccuped inverts the §2 crash policy — host networking outlives the container, always).

## 33. systemd-repart + veritysetup first-boot provisioning (partition seed, hash-tree precompute, factory-reset wipe semantics)

Provisioning is image-verified and first-boot-sealed: `systemd-repart` grows the seeded partition table to full flash on first boot; `veritysetup` binds the read-only system/vendor images to dm-verity hash trees precomputed at factory; factory reset wipes only the named writable partitions with crypto-erase semantics — never the verity roots, never the bootloader without explicit two-confirmation + typed-SKU path (§12). Seed definitions (`repart.d/*.conf`, committed, `repart --dry-run` golden in CI):

```ini
# repart.d/10-esp.conf
[Partition]
Type=esp
Format=vfat
SizeMinBytes=256M
SizeMaxBytes=512M
Label=HALIDE_ESP
# repart.d/20-system.conf (dm-verity protected, read-only)
[Partition]
Type=root-arm64
Format=erofs
SizeMinBytes=2G
SizeMaxBytes=3G
Label=HALIDE_SYSTEM
Verity=data
VerityMatchKey=halide-system
ReadOnly=yes
# repart.d/30-vendor.conf
[Partition]
Type=usr-arm64-verity
Format=erofs
SizeMinBytes=1G
SizeMaxBytes=1536M
Label=HALIDE_VENDOR
Verity=data
VerityMatchKey=halide-vendor
ReadOnly=yes
# repart.d/40-userdata.conf (grows to fill; LUKS per ch.08)
[Partition]
Type=linux-generic
Format=ext4
Label=HALIDE_USERDATA
SizeMinBytes=4G
GrowFileSystem=yes
Encrypt=yes
FactoryReset=yes
```

Hash-tree precompute (factory, not first-boot — first-boot CPU time is user-waiting time, factory time is free): `veritysetup format --hash-offset ... /dev/disk/by-partlabel/HALIDE_SYSTEM /dev/disk/by-partlabel/HALIDE_SYSTEM-verity` per root, roothash recorded into the release manifest + signed alongside the OTA metadata (ch.09 — roothash mismatch at boot = red `VERIFY-FAIL` state, never silent fallback to unverified). First-boot provisioning unit (`halide-repart-provision.service`, runs once before `halide-android.service`):

```ini
[Unit]
Description=HALIDE first-boot repart+verity provisioning
ConditionFirstBoot=yes
After=systemd-repart.service
Before=halide-android.service systemd-growfs@home.service
Requires=dev-disk-by\x2dpartlabel-HALIDE_SYSTEM.device
[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/sbin/halide-provision --repart --verify-hashes --luks-format --expand-userdata
ExecStartPost=/usr/sbin/halide-provision --write-factory-marker /var/lib/halide/factory-sealed
StandardOutput=journal+console
[Install]
WantedBy=sysinit.target
```

`halide-provision` steps (ordered, each journal-tagged `PROVISION=<step>` with timing — first-boot budget §22 ≤6 min includes this): (1) `systemd-repart --dry-run --json=short` diff vs golden (unexpected pre-existing table → abort to recovery with "unexpected storage layout" card, never blind repartition), (2) `systemd-repart` grow + `systemd-growfs` userdata expand, (3) LUKS format userdata if unencrypted (ch.08 argon2id params; keyslot in TPM/recovery-QR per ch.08 — provision refuses to continue without a sealed key path), (4) `veritysetup open --data-block-size 4096 --hash-block-size 4096` both verity pairs + roothash compare against manifest (mismatch → red state + halt, no container start), (5) write factory-sealed marker + `SYSTEMD_REPART_MKFS=no` stamp so subsequent boots skip mkfs (re-running mkfs on userdata post-user-data is the data-loss shape this marker exists to prevent).

Factory-reset wipe semantics (per-partition table — support reads this verbatim on "will I lose X" calls):

| Partition | Reset action | Method | Preserved |
|---|---|---|---|
| `HALIDE_USERDATA` (home + `/data/android`) | wipe | LUKS crypto-erase (keyslot destroy) + `repart --factory-reset=yes` remkfs | nothing (two confirms + typed SKU §12) |
| `HALIDE_SYSTEM` / `HALIDE_VENDOR` (+verity hash partitions) | verify, never wipe | roothash re-check only | always (reset never reimages system; OTA owns system per ch.09) |
| ESP / persist / EFS / calibration | untouched | no entry in reset path; persist/EFS `neverallow` §20 restated | device keys, calibration, MACs |
| pstore / journal / metrics (§19) | wipe with userdata | keyslot-destroy covers; no separate preserve | wipe-attestation line only (§12 P3) |

Expected outputs: `systemd-repart --dry-run --json=short | jq .` matches `repart/golden-<sku>.json` (CI gate on VIRT + per-SKU sacrificial); `veritysetup status halide-system` shows `hash type: sha256, data blocks N, hash blocks M, salt ..., root hash <manifest>` + `journalctl -t halide-provision | grep PROVISION` shows all five steps `OK` with total <90 s on REF-A eMMC; `tests/provision-reset.sh` matrix green (fresh-seed → provision → boot ≤45 s §2 budget; reboot → marker skips mkfs + SMS count stable §12; factory-reset fixture → userdata crypto-erased + system roothash unchanged + wipe-attestation present + first-boot wizard reappears §22).

Idempotency + anti-rollback (the two shapes that brick fleets): provision is re-runnable — second boot sees `factory-sealed` + `SYSTEMD_REPART_MKFS=no` and skips steps 1–3 (verify-only: roothash re-check + LUKS unlock test, no mkfs, no repartition; `PROVISION=skip-sealed OK` line proves the path). Anti-rollback: manifest carries `verity_min_version` + `repart_layout_version`; provision refuses to boot a system image older than the fused minimum (`ROLLBACK_REFUSED` red state + recovery card "update required" — downgrade-to-vulnerable-system via flashed old image is the ch.08 verified-boot threat restated here as a provision gate). `veritysetup status` golden excerpt (normalized, roothash compared verbatim):

```
type:    VERITY
hash type: sha256
data block: 4096 hash block: 4096
data blocks: 524288 hash blocks: 16384
salt:      a41f...c9 (per-release, manifest-pinned)
root hash: 7f3a...e2 (== MANIFEST.debian system_roothash)
```

`tests/provision-reset.sh` core (sacrificial + VIRT; refuses dogfood IDs per §24 debug rule — repartitioning a dogfood daily-driver is a career event):

```bash
halide-provision --dry-run --json | diff - repart/golden-ref-a.json || fail repart-drift
veritysetup status halide-system | grep -q "$MANIFEST_ROOTHASH" || fail roothash-mismatch
halide-factory-reset-fixture --confirm-typed SKU-REF-A --slot other || fail reset-fixture
[ -f /var/lib/halide/factory-sealed ] && fail marker-survived-reset
journalctl -b | grep -q "WIPE_ATTESTATION" || fail attestation-missing
```

Recovery escape: interrupted provision (power cut mid-repart) reboots into initrd `halide-provision-resume` (replays from journal `PROVISION=` last-OK step — repart operations are atomic per-partition so resume never half-formats; userdata LUKS format interrupted pre-keyslot-seal is re-run from scratch with fresh salt, never resumed onto a half-keyslot).

## Verification

- [ ] Cold boot → Phosh lock ≤45s; `systemctl is-system-running` = running/degraded (degraded only with listed cause).
- [ ] Container crash ×3 → host stays up with banner; logs exportable via Settings.
- [ ] Permission grant/revoke sync both directions ≤10s; VPN egress test passes both sides.
- [ ] `SOCKETS.md` matches `ss -x` on device (audit script green).
- [ ] Backup→reset→restore round-trip preserves contacts/SMS exactly on REF-A.
- [ ] `systemd-analyze verify` green on all units; `plot.svg` matches §2 design (no stray Wants).
- [ ] Log-export tarball passes redaction check (seeded IMEI absent); storage-guard harness green at 95% /var.
- [ ] `getent` + `ss -x` + `mount` match the three boundary files (zero drift); overnight residency >90% with budget table signed.
- [ ] `cgroup-audit.sh` green (live MemoryMax/TasksMax/CPUWeight match committed drop-ins); pressure-hog test kills inside container first, Calls still rings.
- [ ] 20 clean poweroffs + 20 reboots + 5 forced cutoffs pass `shutdown-drain.sh` (clean markers, SMS preserved, no bridge-DB corruption; attach ≤90s post-reboot).
- [ ] Locale runtime matrix green (12 locales host→container ≤5s, Android-side set denied+logged, reboot-persistent, travel suggests-not-applies).
- [ ] Settings-search perf ≤200ms p95 + `search-gate.sh` green (no unindexed panels/intents; badge assertion passes).
- [ ] Time-vote fixtures green (NTP-wins-on-diverge, forward-live/backward-drain, RTC_SUSPECT holdover, alarms re-fire). `systemctl is-system-running` = running/degraded (degraded only with listed cause).
- [ ] Container crash ×3 → host stays up with banner; logs exportable via Settings.
- [ ] Permission grant/revoke sync both directions ≤10s; VPN egress test passes both sides.
- [ ] `SOCKETS.md` matches `ss -x` on device (audit script green).
- [ ] Backup→reset→restore round-trip preserves contacts/SMS exactly on REF-A.
- [ ] `systemd-analyze verify` green on all units; `plot.svg` matches §2 design (no stray Wants).
- [ ] Log-export tarball passes redaction check (seeded IMEI absent); storage-guard harness green at 95% /var.
- [ ] `getent` + `ss -x` + `mount` match the three boundary files (zero drift); overnight residency >90% with budget table signed.

Next: `06-graphics-wayland-phosh-bridge.md`.
