// audio-hal.cpp - NO COMPILE FOR NOW (text only per 00 banner).
// Production AudioFlinger->PipeWire proxy HAL is C++ (MMAP, quantums, xruns).
// Mirrors bridges/audio_bridge.py logic for the builder to compile later.
#include <string>

enum Node { MEDIA = 0, CALL = 1, ALARM = 2 };

static bool g_call_active = false;

// Call preempts media: route(media) while call active => ducked (1), else 0.
int halide_audio_route(int node) {
  if (node < 0 || node > 2) return -1;
  if (g_call_active && node == MEDIA) return 1;  // ducked
  if (node == CALL) g_call_active = true;
  return 0;
}

int halide_audio_volume(int node, int vol) {
  if (node < 0 || node > 2) return -1;
  if (vol < 0 || vol > 100) return -1;
  return 0;
}
