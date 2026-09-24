# hardware/halide/camera/stride-notes.md - ISP stride notes (ch.04 S7/S9/S37).
# Green frames = stride/format mismatch until proven otherwise. Isolate first:
# force NV12 + fixed stride before touching the ISP.
# Pipeline: kernel CAMSS -> host libcamera -> provider@2.7-halide adapter
# (EXTERNAL-camera heritage, libcamera-backed). Gralloc format
# HAL_PIXEL_FORMAT_YCbCr_420_888. HAL3 pipeline depth 8 (REF-A; libcamera
# Request queue matched 1:1 - deeper HAL3 queue = head-of-line stall).
# Request lifetime p50/p99: 1080p30 33/55ms; 12MP still 180/350ms.
# flush() <=500ms (600ms watchdog -> CAMERA-FLUSH-TIMEOUT + force streamOff);
# configureStreams <=800ms; close() <=300ms, zero leaked gralloc buffers.
# Stride rule: stride = ALIGN(width,64). Per-resolution table (REF-A):
resolution,width,height,stride_bytes,format,notes
preview,1920,1080,1920,NV12,1920 already 64-aligned; 1080p30+12MP default combo
record,1920,1080,1920,NV12,60s hold, dropped_frame_counter 0
low-light,1280,720,1280,NV12,720p30 preview-only; AE settle <=2s
still-max,4000,3000,4032,NV12,4000 -> ALIGN 4032; JPEG still <=350ms stall
front,1920,1080,1920,NV12,mirror=true selfie path (S31 asymmetric-target check)
# Reprocess OFF v1 (YUV/PRIVATE_REPROCESSING -> NOT_SUPPORTED, tested).
# INFO_SUPPORTED_HARDWARE_LEVEL LIMITED v1 (never FULL/LEVEL_3 without proof).
# SENSOR_ORIENTATION formula lives in camera/<sku>/<sensor>.md (S31) with
# numbers shown, not just the result. EXIF Orientation tag always written.
