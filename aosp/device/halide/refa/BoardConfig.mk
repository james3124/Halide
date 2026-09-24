# halide refa BoardConfig - text-only stub
TARGET_ARCH := arm64
TARGET_ARCH_VARIANT := armv8-a
TARGET_CPU_ABI := arm64-v8a
AB_OTA_UPDATER := true
AB_OTA_PARTITIONS += system vendor
BOARD_BUILD_SYSTEM_ROOT_IMAGE := true
# slot suffix _a used for A/B (e.g. system_a)
