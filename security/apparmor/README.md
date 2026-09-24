# apparmor/README.md -- AppArmor merge artifact (ch.08 S10 + S31, sepolicy-deltas S5 sync table)
# Owner: Security + Platform

Canonical profiles (this dir, enforced -- aa-status enforcing is a release gate):

| Profile          | Confines            | Socket allowlist source |
|------------------|---------------------|-------------------------|
| halide-android   | LXC container       | SOCKETS.md bridge paths |
| halide-bridges   | bridge daemons      | SOCKETS.md per-bridge   |
| halide-composer  | host composer       | wayland + input + dri   |

Harness alias: ../apparmor-lxc-android is a symlink to halide-android
(tests/apparmor-seccomp.sh greps that path; single source, no duplicate).

Three-way sync (sepolicy-deltas S5): every SOCKETS.md path must appear in
(1) the .te allow row, (2) the AppArmor rule above, (3) the seccomp JSON in
../seccomp/. Any socket in one but missing in another fails CI (mac-sync gate).

Exception discipline: BUG + EXPIRY + TEST comment per rule (ch.08 S4).
Complain mode: lab-only, dated 48h tag, blocks release while present.
