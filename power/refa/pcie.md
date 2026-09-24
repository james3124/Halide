# pcie.md - REF-A PCIe ASPM idle-delta record (ch.03 S35)
# Owner: Net/Kernel + Power. Endpoint: Wi-Fi ath10k/cnss (+ NVMe where present).
# Policy: pcie_aspm=force + L1SS where endpoint advertises (cmdline registry
# pins pcie_aspm=force; `off` without a power note here fails review).
# WHY this file exists (S35): ASPM-off powers through suspend and the wakeup
# audit names it. The measured idle delta below is the receipt.

## Link training log (per release; downgraded link investigated as SI/power,
## never accepted silently - S35)
# Commands: dmesg | grep -i pcie (L0s/L1 + width x speed negotiated vs DT
# max-link-speed); PERST timing + REFCLK (clk_summary) + vdda sequencing on
# no-link (fault ladder: PERST -> REFCLK -> regulator -> LTSSM dump ->
# reseat/reflow with traveler ID ch.04 S17).

| Endpoint | Expected | Negotiated | ASPM state | Date | Notes |
|---|---|---|---|---|---|
| WCN3990 Wi-Fi (ath10k/cnss) | x1 Gen2, L1SS | PENDING-HW-RUN | PENDING | seed | SEED row - fill on first bring-up |
| NVMe (if present) | per datasheet | N/A-or-PENDING | N/A | seed | record absent/present (v1 informational) |

## ASPM idle-delta measurement (SEED - procedure pinned, numbers pending HW)
# Method: external meter, airplane-idle screen-off 1h, ASPM force+L1SS vs
# ASPM off; same ambient footnote per ch.10 S8. USB autosuspend held at
# policy values (S35) so USB does not leak into the PCIe delta.
# Expected shape (plan carry, re-measure): ASPM-off adds single-digit mA that
# the suspend audit attributes to the PCIe row, not to modem-DRX.
ASPM_ON_MA=PENDING
ASPM_OFF_MA=PENDING
ASPM_IDLE_DELTA_MA=PENDING
MEASURE_DATE=PENDING
AMBIENT_FOOTNOTE=PENDING

## Reset sequencing (per-endpoint, S35)
# reset-assert-ms / deassert from datasheet with scope-capture on first
# bring-up. PCIe devices held in reset 10ms that need 100ms enumerate
# intermittently and waste months - the scope capture lives with hw bring-up.
WCN3990_RESET_ASSERT_MS=PENDING-datasheet
WCN3990_RESET_DEASSERT_MS=PENDING-datasheet
SCOPE_CAPTURE=PENDING

## IRQ mode (S35)
# /proc/interrupts must show MSI per endpoint. Legacy IRQ sharing with the
# touch IRQ is a latency bug for ch.06 S7 touch p95 - checked once per SKU.
IRQ_MODE=PENDING-check-once-per-SKU

## Verification
# - [ ] Link width/speed == DT max-link-speed (or SI/power BUG filed).
# - [ ] Idle delta filed above; ASPM-off-in-release would reference this file.
# - [ ] MSI confirmed; no legacy share with touch IRQ.
