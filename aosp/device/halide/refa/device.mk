# device/halide/refa/device.mk - REF-A product definition (ch.04 S16, ch.03 S34).
# Lunch target: halide_refa-userdebug (eng bring-up only, never release).
# Release-branch lunch guard: eng refused in CI (ch.04 S16); fastboot -w
# requires typed SKU confirmation, never scripted blindly.

# Dalvik heap sizing, matched to zram (ch.03 S34). Heap too large + small
# zram = direct-reclaim stalls visible as scroll jank. Per-RAM-variant split:
# 4GB units use the 256m limit; 6GB+ units use 384m. Never one shared value.
PRODUCT_PROPERTY_OVERRIDES += dalvik.vm.heapgrowthlimit=256m
PRODUCT_PROPERTY_OVERRIDES += dalvik.vm.heapmaxfree=8m
# 6GB+ variant overlay (device/halide/refa-6gb/device.mk): heapgrowthlimit=384m.
# DRAM-size fork (ch.02 S19): container lmkd props per-variant, never shared.

# lmkd PSI mode (ch.03 S34): container lmkd kills container processes only.
# Host systemd-oomd is monitor-only on the container subtree (action none);
# pressure is forwarded via /run/halide/memory-pressure, kill decision stays
# in the stack that understands adj scores.
PRODUCT_PROPERTY_OVERRIDES += ro.lmk.psi_complete_stall_ms=150
PRODUCT_PROPERTY_OVERRIDES += ro.lmk.psi_partial_stall_ms=200
PRODUCT_PROPERTY_OVERRIDES += ro.lmk.thrashing_limit=100

# RIL shim path (ch.04 S4): rild + libril-halide to QRTR. gsm.version.ril-impl
# is asserted set by halide-android-health; SIM READY via telephony.registry.
PRODUCT_PROPERTY_OVERRIDES += vendor.rild.libpath=/vendor/lib64/libril-halide.so
PRODUCT_PROPERTY_OVERRIDES += persist.vendor.radio.log_loc=/data/vendor/radio/logs

# Hybrid version truth (ch.04 S15): container build.prop halide.version must
# major-match host /etc/halide-release or halide-android-prepare refuses.
PRODUCT_PROPERTY_OVERRIDES += ro.halide.sku=refa
PRODUCT_PROPERTY_OVERRIDES += ro.halide.version=$(HALIDE_VERSION)

# Vendor modules expected in vendor_boot/vendor_dlkm (ch.04 S17). Boot fails
# closed if a listed module is missing; list lives in vendor_module_list.txt.
# PRODUCT_PACKAGES (HAL services registered in manifest.xml, ch.04 S19):
PRODUCT_PACKAGES += \
    audio.primary.halide \
    android.hardware.camera.provider@2.7-service-halide \
    android.hardware.sensors@2.1-service-multihal \
    android.hardware.gnss@2.1-service-halide \
    android.hardware.power-service-halide \
    android.hardware.health-service-halide \
    android.hardware.usb-service-halide \
    android.hardware.lights-service-halide \
    android.hardware.vibrator-service-halide
