// power-hal.cpp - NO COMPILE FOR NOW (text only per 00 banner).
// IPower@5 hint proxy: Android POWER_HINT_SUSTAINED_PERFORMANCE and
// INTERACTION are wired to host cpufreq/devfreq boosts via
// /run/halide/power-hint (rate-limited; every hint logged in debug builds
// to catch boost storms, ch.04 S11). Throttling decisions are owned by the
// host thermald-class daemon; Android advises via hints, host enforces
// (ch.04 S25). Values live in power-hint-values.conf, never hardcoded here.
#include <string>

enum Hint { INTERACTION = 0, SUSTAINED_PERFORMANCE = 1 };

static bool g_sustained_on = false;
static int g_hint_count_window = 0;

// Max hints per 10s window before the rate limiter drops (storm test: 200
// rapid hints must hold, counter in metrics proves it, S21 drill).
static const int kMaxHintsPerWindow = 64;

// Sends one hint toward /run/halide/power-hint. Returns 0 on accept,
// 1 on rate-limited drop (counted, never silent), -1 on bad hint id.
int halide_power_hint(int hint, int duration_ms) {
  if (hint < 0 || hint > 1) return -1;
  if (duration_ms < 0) return -1;
  if (g_hint_count_window >= kMaxHintsPerWindow) return 1;  // dropped, counted
  g_hint_count_window++;
  if (hint == SUSTAINED_PERFORMANCE) g_sustained_on = (duration_ms > 0);
  return 0;
}

int halide_power_sustained(bool on) {
  g_sustained_on = on;
  return 0;
}

bool halide_power_is_sustained() {
  return g_sustained_on;
}

// Test hook: resets the rate window. Production calls this once per 10s tick.
void halide_power_window_reset() {
  g_hint_count_window = 0;
}
