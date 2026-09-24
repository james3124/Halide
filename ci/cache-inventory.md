# cache-inventory.md — normative cache register (ch.09 §18: each cache has key + store + threat model).
# NO-COMPILE on phone: this file documents builder-side caches; nothing here runs on the phone.

| Cache | Key schema (all include MANIFEST.lock SHA + builder digest + toolchain) | Store | Size cap | Threat model |
|---|---|---|---|---|
| ccache/sccache objects | `<manifest-sha8>-<builder-digest12>-<clang-ver>` + branch-scoped suffix | builder-local NVMe + shared S3-equivalent bucket | 50–100GB per builder (NVMe, GC oldest namespace first) | cache poisoning via mixed manifests — different manifest = cold cache by construction (ch.09 §7) |
| AOSP frozen-fetch tarballs | `<manifest-sha>-<fetch-stage-hash>` | content-addressed store, SHA-verified on read | 200GB | poisoned proxy serves bytes that fail verification, never bytes that build (ch.09 §13) |
| Debian snapshot proxy (apt-cacher-ng) | `<snapshot-stamp>-<arch>` (bookworm-20260101) | snapshot-stamped cache | 50GB | pin drift — fetch verifies against packages.lock (ch.09 §13) |
| Container layer cache | `<dockerfile-digest>` | builder image layers by digest | registry GC | digest-pinned images only; floating tags banned (ch.09 §7) |

Rules (short, binding, ch.09 §18):
- Never share a cache bucket across trust zones (public-fork PRs use an isolated bucket).
- Weekly cache-bypass canary build; divergence = CACHE-SUSPECT P0, cache quarantined.
- No other caches permitted; undocumented caches fail the audit (cache-rotations.md logs every rotation).
