// halide-composer.cpp - NO COMPILE FOR NOW (text only per 00 banner).
// Production SurfaceFlinger->Wayland composer is C++ (fences, dma-buf, vsync).
// Phone holds the source text; builder compiles. No g++ invoked here.
#include <string>
#include <map>

enum Layer { STATUS = 0, APP = 1, VIDEO = 2, OVERLAY = 3 };

// graphics/prio-map.txt is the source of truth; mirror it here.
static const std::map<std::string, int> kPrio = {
    {"status", 0}, {"app", 1}, {"video", 2}, {"overlay", 3},
};

// Returns 0 on plan/dry-run. Real present() runs on builder only.
int halide_present(const std::string& layer, int fence_fd) {
  if (kPrio.find(layer) == kPrio.end()) return 2;  // unknown layer
  if (fence_fd < 0) return 2;                       // bad fence
  return 0;
}
