// prop-bridge.cpp — NO COMPILE FOR NOW (text only per ch.00 banner).
// C++ implementation of the prop->dbus bridge; mirrors bridges/prop_bridge.py
// protocol byte-for-byte (contract: tests/test_bridges.py + bridges/tests/).
// Builder compiles (AOSP/Debian toolchain per ch.05 §8); phone runs the Python
// twin for logic checks. On conflict: host wins; allowlist is the consent source.

#include <algorithm>
#include <array>
#include <cctype>
#include <map>
#include <string>
#include <string_view>

namespace halide {

// Allowlist — MUST stay byte-identical to bridges/prop_bridge.py ALLOWLIST and
// bridges/prop-allowlist.txt (ch.00 registry: single consent source; drift fails CI).
constexpr std::array<std::string_view, 3> kAllow = {
    "persist.sys.locale",
    "persist.sys.timezone",
    "sys.boot_completed",
};

constexpr size_t kMaxValueLen = 256;  // matches Python twin "ERR too-long"

bool allowed(std::string_view key) {
  return std::find(kAllow.begin(), kAllow.end(), key) != kAllow.end();
}

// One request line -> one response line (protocol in bridges/prop_bridge.py docstring):
//   REQ:  "GET <key>\n" | "SET <key> <value>\n"
//   RESP: "OK <value>\n" | "OK\n" | "ERR <reason>\n"
class PropBridge {
 public:
  std::string handle(std::string_view line) {
    line = trim(line);
    if (line.empty()) return "ERR empty\n";

    const auto sp1 = line.find(' ');
    if (sp1 == std::string_view::npos) return "ERR bad-command\n";

    std::string_view cmd = line.substr(0, sp1);
    std::string_view rest = line.substr(sp1 + 1);

    if (ieq(cmd, "GET")) {
      if (rest.find(' ') != std::string_view::npos) return "ERR bad-command\n";
      if (!allowed(rest)) return "ERR denied\n";
      auto it = store_.find(std::string(rest));
      return it == store_.end() ? std::string("OK \n")
                                : "OK " + it->second + "\n";
    }

    if (ieq(cmd, "SET")) {
      const auto sp2 = rest.find(' ');
      if (sp2 == std::string_view::npos) return "ERR bad-command\n";
      std::string_view key = rest.substr(0, sp2);
      std::string_view val = rest.substr(sp2 + 1);
      if (!allowed(key)) return "ERR denied\n";
      if (val.size() > kMaxValueLen) return "ERR too-long\n";
      store_[std::string(key)] = std::string(val);
      return "OK\n";
    }

    return "ERR bad-command\n";
  }

 private:
  static bool ieq(std::string_view a, std::string_view b) {
    if (a.size() != b.size()) return false;
    for (size_t i = 0; i < a.size(); ++i)
      if (std::toupper(static_cast<unsigned char>(a[i])) !=
          std::toupper(static_cast<unsigned char>(b[i]))) return false;
    return true;
  }
  static std::string_view trim(std::string_view s) {
    while (!s.empty() && (s.front() == ' ' || s.front() == '\t')) s.remove_prefix(1);
    while (!s.empty() && (s.back() == ' ' || s.back() == '\t' ||
                          s.back() == '\r' || s.back() == '\n')) s.remove_suffix(1);
    return s;
  }
  std::map<std::string, std::string> store_;  // single-threaded: 1 conn at a time (ch.05 §9)
};

}  // namespace halide
