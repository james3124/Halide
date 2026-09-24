# seccomp/README.md -- seccomp-bpf allowlists per bridge (ch.08 S10)
# Owner: Bridge owner + Security * Review: per-MR (parsers touched => fuzz-smoke) + quarterly
# Rules (binding): execve denied in bridges (no shell-out from parsers -- RCE
# containment); ptrace denied; allowlist covers event-loop + socket + binder-ioctl
# families only. Fuzz corpus: halide-fuzz-bridges (10-min MR smoke, 4h nightly).

Bridges covered: ril, sms, audio, prop (composer inherits the bridge-deny shape
via halide-bridges AppArmor + no-exec; its syscall surface is documented here
only where it differs -- see ril.json notes field pattern).

Schema per file: {"bridge": str, "default_action": "SCMP_ACT_ERRNO",
"syscalls": [{"names": [...], "action": "SCMP_ACT_ALLOW", "reason": str}], ...}
Every entry needs "reason"; entries without reason fail sepolicy-comment-lint
adjacent review (same least-privilege doctrine as S31).
