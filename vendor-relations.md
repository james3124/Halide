# HALIDE Vendor Relations — Firmware, NDAs, Blobs, Upstream

**Parent: ch.02 hardware-matrix · ch.04 HAL pins · ch.07 modem · ch.11 risks/licenses · Owner: Arch + Legal + BSP**

## 1. Firmware and datasheet request playbook

Ask narrowly, cite exact need, offer redacted proof of progress. Vendors answer specific bring-up questions; they ignore "send everything".

1. Inventory first: check ch.02 blob table + appendix-04A hal-dumps before asking. Never request what we already have.
2. Request template (one page): who (HALIDE project, device+SKU, MANIFEST range), what (exact doc/PN/rev or FW version + why: e.g., "MIPI DSI init seq for panel X, needed for DRM/KMS bring-up ch.06"), what we tried (UART log excerpt redacted + `modetest` output), what we sign (see §2 positions), redistribution ask stated upfront (see §3).
3. Escalation ladder: FAE → product-line manager → second-source RFQ (§5). Each step adds lab data, not pressure. Log every exchange in `vendor/<vendor>-<part>.md` (date, contact, asked/got/pending) — institutional memory survives engineer churn.
4. Redaction on our side too: never send user PII, fleet serials, or keys. Support-log-script redaction applies to vendor tickets.

```bash
halide-vendor-pack --for sdm845-panel --redact --out /tmp/vendor-panel-pack.tgz
# Expected: redacted dmesg + modetest + DT snippet + precise question sheet, no IMEI/keys/serials
# Gotcha: overbroad ask ("all modem docs") triggers legal review on their side and stalls months
# Fix: split into one ask per interface (panel / power-domains / modem-QRTR) with separate ticket ids
```

Honesty rule: never claim certification, volume, or GMS/Widevine roadmap we do not have to extract docs. No fake claims, ever.

## 2. NDA evaluation rubric (what we sign vs refuse)

| Clause | Sign | Refuse / renegotiate | Rationale |
|--------|------|----------------------|-----------|
| Bilateral, 2–3yr term, narrow scope (named parts) | yes | — | covers bring-up without blanket gag |
| Residual-knowledge carve-out | require | refuse if absent | engineers keep general skills; without it we cannot staff |
| Open-source carve-out (mainline/GKI upstreaming allowed) | require | refuse if absent | single LTS+GKI kernel strategy depends on upstream |
| Unilateral, >5yr, "all communications" scope | — | refuse | unbounded liability, kills upstream etiquette (§4) |
| No-reverse-engineering beyond license | — | refuse | conflicts with interop debugging + GPL rights |
| Royalty/audit-by-vendor, volume commitments | — | refuse / move to purchase contract, not NDA | NDAs are for information, not commercial lock-in |

Process: Legal reviews every NDA; BSP adds technical-need note; Arch signs. Refusals use polite template: "We can sign narrow bilateral with residual + OSS carve-outs; here is our one-page markup." Most FAEs accept the markup when the ask is narrow (§1).

## 3. Blob-redistribution negotiation positions

Opening positions (negotiable, but never the bottom row):

| Ask | Position | Fallback |
|-----|----------|----------|
| Redistribute FW in HALIDE images + OTA | require for daily-driver SKUs | vendor-hosted URL + firstboot fetcher with SHA pin (worse UX, documented) |
| Redistribute in CI/lab images | require | per-seat download with shared cache keyed by SHA (no leaky binaries in git) |
| Version-pin + SHA in MANIFEST | non-negotiable | no floating "latest" blobs, ever (reproducibility DoD) |
| Debug symbols / symbolized traces | ask | redacted tombstone + `halide-wa-audit` output instead |

Never commit to per-unit royalties inside an NDA; pricing lives in a supply contract with second-source comparison (§5). SBOM/license packet (ch.09/ch.11) lists every blob with SHA, license, redistribution right — unlisted blobs fail factory traveler. Staged rollouts cover blob updates with radio-bake 1% 24h + auto-halt; modem FW bumps need carrier re-qual per modem-fw-qualification.

## 4. Upstream-collaboration etiquette with vendor engineers

1. Reproduce mainline-first before tagging vendor: same bug on LTS+GKI tip + minimal DT overlay, `dmesg` + bisect hint attached. Vendor engineers triage upstreamable reports first.
2. One thread per issue, subject `HALIDE <SoC>/<SKU>/<MANIFEST-short>: <symptom> + <register/trace>`. Include Expected vs actual (honesty rules travel upstream too).
3. Credit and boundaries: credit vendor fix in commit + release notes; never paste NDA material into public lists. Keep a clean-room boundary: NDA docs inform questions, never appear verbatim upstream. Permission-atomicity and single-stack NM design explained once per vendor (link, don't re-argue) to avoid "just use netd" loops.
4. Give back: send DT bindings, power-domain notes (appendix-03B), and test results upstream even when painful — the next bring-up (appendix-03A pattern) gets faster answers.

## 5. Second-source leverage ethics

Second-sourcing is resilience, not coercion. Rules: never bluff a switch we cannot execute (BSP must confirm pin/DT feasibility first); never share vendor A's pricing/docs with vendor B; RFQs state evaluation criteria (docs openness, redistribution, upstream posture, power/thermal data) identically to all bidders. Switching decisions recorded in ch.11 risk register with owner + trigger date, not hallway threats. Goal: two qualified sources for panels, batteries, and modem FW tracks where feasible — reported honestly even when single-sourced (customers deserve the risk statement, not comfort).

## Verification

- [ ] Every vendor ask has narrow ticket + redacted pack + log in `vendor/`; no "send everything" tickets.
- [ ] Signed NDAs meet rubric (bilateral, narrow, residual + OSS carve-outs); refusals used template.
- [ ] All blobs SHA-pinned with redistribution right in SBOM; no floating blobs; radio-bake + halt armed for FW OTAs.
- [ ] Upstream threads mainline-first with Expected/actual; no NDA text in public; vendor fixes credited.
- [ ] Second-source status per critical part recorded in risk register; no bluff without BSP feasibility note.
