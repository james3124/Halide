# Release notes template -- every release, same sections (ch.09 S14).
# Comparability is the feature. Fluffy "minor bugs" entries rejected in review:
# each issue names failing behavior + who it hurts (P1/P2/P3) + workaround-or-none.
# Published before rollout passes 10 pct. ASCII only.

halide-vX.Y.Z+<sku> (<date>) -- <one-line theme>
GATES: dogfood <pass/fail + P0/P1 counts> | CTS/VTS <x/y + quarantined z> | power <link sheet>
IMAGES: <hashes + sizes> | MANIFEST.lock <sha> | builder digests <both>
SBOM DIFF: +<new> ~<upgraded> -<removed> (new blobs named, ch.09 S11)
CARRIERS: <blessed list + emergency statuses + perf deltas>
COMPAT: <TOP-100 hit-rate + notable moves>
KNOWN ISSUES: <each with bug + workaround-or-none + target>
CVE DISPOSITIONS: <patched/not-affected/mitigated per ch.08 S11>
UPGRADE: <full/delta wire sizes + battery requirement + staged pct + deadline if any>
  (UPGRADE numbers auto-filled from logs/ota-sizes-<sku>-<ver>.json; humans add
  the "prefer Wi-Fi" sentence, never the numbers. delta-skipped reasons listed.)
