# Repo Layout — Monorepo Map, Ownership & Merge Rules
**Parent: ch.09 §1, ch.11 §2 RACI · One `hybrid/` tree per builder (paths match ch.00 preamble)**

## 1. Tree (authoritative — new top-level dirs need Arch sign + this file updated same MR)

```
hybrid/
  manifests/            # MANIFEST.lock (super-pin) + per-root pins (kernel/aosp/debian/mesa/keys-id)
  kernel/               # linux/ (mainline, never patched in place*) + gki/ + halide-base.fragment +
                        # devices/<sku>/ + vendor_modules/<name>/ (+UPSTREAMING.md each) + TECH-DEBT.md
  aosp/                 # .repo/manifests/halide.xml + device/halide/ + vendor/halide/ + hardware/halide/
  debian/               # packages.host (WHY-commented) + hooks/ + overlays/halide-* (bridges, composer, units)
  bridges/              # proto/*.proto + SOCKETS.md + permission-map.csv + prop-allowlist.txt + tests/ + fuzz/
  graphics/             # prio-map.txt + <sku>/panel.json + <sku>/modifiers.conf + <sku>/limits.conf
  audio/                # <sku>/policy.json + call-gains.conf + measurements.md + tuning-<ver>.md + tinymix-baseline.txt
  camera/               # <sku>/<sensor>.md + <sensor>-tuning-<ver>.md
  sensors/ telephony/ gnss/ rf/ thermal/ power/ carrier/ hw/ images/ factory/ security/ program/ compat/
  scripts/              # build-all.sh + assemble + dump-diff + socket-audit + mac-sync-check + sbom.sh +
                        # license-check.sh + carrier-lint + perf-footnote-lint + kernel-bisect + regulator-audit
  tests/                # harness scripts (§7 ch.10 contracts: exit 0/1/2) + cts-allowlist.txt + quarantine.txt
  ci/                   # Dockerfile (digest-pinned) + packages.lock + jobs (mr/nightly/release per ch.09 §11)
  keys/                 # pubs + metadata ONLY (scanner-enforced, ch.08 §8)
  logs/ sbom/ support/ porting/ recovery/ debian-hooks/
```

*Kernel patch rule: mainline `linux/` stays pristine (`git status` clean enforced pre-build, ch.03 §11) — our changes live as fragments/overlays/modules (bisectable + upstreamable by construction; pristine-tree violations fail CI with the dirty files named).

## 2. Ownership (CODEOWNERS excerpt — review routing, not fiefdoms)

```
kernel/ devices/ arch/                    @bsp-lead @arch
aosp/device aosp/vendor aosp/hardware     @android-lead @arch
debian/ bridges/ graphics/composer        @platform-lead @arch
bridges/ril* telephony/ carrier/          @telephony @platform-lead
security/ keys/                           @security @arch (2-person: +area owner)
images/ factory/ ci/ scripts/build*       @release @arch
tests/ power/ thermal/                    @qa (gate-sign authority per ch.00 phase gates)
compat/ support/ program/                 @program (docs review: owner + one user-voice)
*.md (plan docs)                          @author + @area-owner (wc-budget check automated)
```

Anyone may review anything (drive-by reviews welcome); CODEOWNERS are required approvers (missing-approval merge blocked branch-side, not by honor system).

## 3. Merge rules (branch protection as code — settings exported in `ci/branch-protection.json`)

`main`: release-train only (RC + ceremony, ch.09 §11) — direct push disabled, 2 signs (area + Arch for cross-cutting), CI full-green, SBOM-diff attached for image-affecting. `develop`: nightly source — 1 area-owner sign + CI MR-suite green + contract tests for touched bridges + fuzz-smoke where parsers touched. Feature branches: `feat/<area>-<slug>` (from develop, MR back with gate evidence linked: which hardware run, which logs). Hotfix: `hotfix/<cve-or-p0>` (may branch from main with Release + Security signs, 24h SLA clock from ch.08 §11 rubric). Revert-first culture: red develop >2h without owner action = auto-revert MR by Release (author re-lands fixed — revert stigma explicitly banned in CONTRIBUTING header).

## Verification

- [ ] Branch protection matches exported JSON (drift check in CI); CODEOWNERS cover every dir (unowned-path lint green).
