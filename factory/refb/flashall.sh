#!/bin/bash
# factory/refb/flashall.sh -- refb wired factory flash (ch.09 S10 runbook executed by software).
# Steps: (1) GPT backup gate, (2) flash all per flashmap with verify-after-write,
# (3) fastboot -w only with typed SKU confirm, (4) AVB lock as separate explicit
# step, (5) first-boot smoke trigger. Budget: <= 12 min wired flash.
# PHONE-SAFE: --plan prints the runbook. Any real flash refuses on low-RAM (exit 2)
# and never runs without --i-have-backup or --take-backup-now.
set -eu
cd "$(dirname "$0")/../.."
SKU=refb
MAP=images/$SKU/flashmap.json

if [ "${1:-plan}" = "--plan" ] || [ "${1:-plan}" = "plan" ]; then
  echo "flashall plan sku=$SKU (<=12 min budget, non-engineer usable)"
  echo " 1. GPT backup to operator PC (--take-backup-now writes persist/efs/modemst + GPT with SHA + free-space check)"
  echo " 2. flash all partitions per $MAP with verify-after-write (avbtool info_image re-read + hash compare)"
  echo " 3. fastboot -w ONLY with typed SKU confirm ($SKU)"
  echo " 4. AVB lock: separate step, checkbox + typed LOCK + warning text, never bundled"
  echo " 5. first-boot smoke: reboot, poll boot_completed <=5 min, PASS sticker data for traveler"
  echo "mismatch guard: SKU match vs flashmap, mismatch = big-red-halt, never flash REF-B images into REF-A"
  echo "flashall: PLAN ONLY (no writes performed)"
  exit 0
fi

HAVE_BACKUP=0
for a in "$@"; do
  [ "$a" = "--i-have-backup" ] && HAVE_BACKUP=1
  [ "$a" = "--take-backup-now" ] && HAVE_BACKUP=1
done
[ "$HAVE_BACKUP" = 1 ] || { echo "REFUSED: backup-first gate (pass --take-backup-now or --i-have-backup)"; exit 2; }

MEM_GB=$(free -g | awk '/^Mem:/{print $2}')
if [ "$MEM_GB" -lt 16 ]; then
  echo "REFUSED: need >=16GB RAM for flash (have ${MEM_GB}GB). Run on the flash station per factory/station-image.md."
  exit 2
fi
if [ -e /system/build.prop ]; then
  echo "REFUSED: /system/build.prop exists (Android phone) -- never flash from the phone."
  exit 2
fi
echo "Station thresholds passed -- full flash not implemented in phone skeleton (run on station)."
exit 2
