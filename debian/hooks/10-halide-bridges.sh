#!/bin/sh
# halide bridges hook stub — echo only, phone-safe
# ch.00 §C registry units: all six installed by this hook (order = boot contract).
set -eu
for unit in halide-early.service \
            dev-binderfs.mount \
            halide.slice \
            halide-android.service \
            halide-prop-bridge.service \
            halide-ril-bridge.service \
            halide-audio-bridge.service \
            halide-netd-bridge.service \
            halide-permission-bridge.service \
            halide-alarm-bridge.service \
            halide-suspend-prepare.service \
            halide-cpufreq.service \
            halide-psi-monitor.service \
            halide-locale-notify.service \
            halide-locale-notify.path \
            halide-time-vote.service \
            halide-settings-index.service \
            halide-firstboot.service \
            halide-dirty-boot.service \
            halide-repart-provision.service \
            halide-backup.service \
            halide-crash-banner.service \
            halide-composer.service \
            halide-bootstage.service \
            halide-ota-finalize.service \
            halide-drain.service \
            halide-power.service; do
  echo "[halide] install overlays: $unit"
  echo "cp debian/overlays/$unit /etc/systemd/system/"
done
echo "[halide] install lxc config template: android.conf.in"
echo "cp debian/overlays/android.conf.in /var/lib/lxc/android/config (builder-generated)"
echo "[halide] install host scripts: halide-android-prepare halide-drain halide-time-vote halide-memory-pressure halide-backup halide-wipe-export halide-firstboot-check halide-provision halide-log-export halide-lxc-check -> /usr/sbin/"
echo "[halide] install net hooks: dispatcher-90-halide.sh halide-dns-merge.sh"
echo "[halide] install configs: nftables.conf chrony.conf timesyncd.conf zram-generator.conf journald/oomd/resource-limits repart.d apparmor seccomp NM-single-stack lxc-checkconfig.expected time-vote.policy"
echo "[halide] daemon-reload + enable halide-drain (shutdown ordering contract)"
echo "[halide] done (no-op stub)"
