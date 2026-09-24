#!/bin/bash
# deploy.sh — PHONE-SAFE: text only, no destructive action.
# Default mode `plan` prints stages only. Any other mode refuses on this phone.
set -eu

MODE="${1:-plan}"
MEM_GB=$(free -g | awk '/^Mem:/{print $2}')
AVAIL_DISK_GB=$(df -BG . | awk 'NR==2{gsub("G","",$4); print $4}')

echo "HALIDE deploy (phone-safe, text only)"
echo "Mem total: ${MEM_GB}GB, disk avail: ${AVAIL_DISK_GB}GB"
echo "Mode: ${MODE}"

if [ "${MODE}" = "plan" ]; then
  echo "Stage: check -> verify manifests/text files only (safe on phone)"
  echo "Stage: bake -> build artifacts on builder only (halt: Mem <16GB or disk <400GB)"
  echo "Stage: flash-plan -> print fastboot/adb steps only, never execute (halt: /system/build.prop exists = Android phone)"
  echo "Stage: rollout 1/10/50/100 with halt reasons (halt: health regression, user abort, threshold fail)"
  echo "plan: no destructive action taken (never runs fastboot/adb flash)"
  exit 0
fi

# Any non-plan mode (flash/ota/push/...) must REFUSE on this phone.
if [ "${MEM_GB}" -lt 16 ]; then
  echo "REFUSED: need >=16GB RAM for '${MODE}' (have ${MEM_GB}GB). Copy hybrid/ to a builder per README.phone-build.md."
  exit 2
fi
if [ "${AVAIL_DISK_GB}" -lt 400 ]; then
  echo "REFUSED: need >=400GB free for '${MODE}' (have ${AVAIL_DISK_GB}GB)."
  exit 2
fi
if [ -e /system/build.prop ]; then
  echo "REFUSED: /system/build.prop exists (Android phone) — refusing '${MODE}' on phone."
  exit 2
fi

echo "REFUSED: '${MODE}' is destructive-adjacent; never runs fastboot/adb flash from phone skeleton (run on builder)."
exit 2
