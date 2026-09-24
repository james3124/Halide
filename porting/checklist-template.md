# New-SKU porting checklist (ch.11 S8: P4 acceptance Phase 1 in <=4 weeks).
# Copy to porting/checklist-<sku>.md. Blessed status requires full Phase-3 DoD
# (no shortcuts - blessed means daily-driver); community-supported needs steps
# 1-7 logs committed + 50-cycle suspend pass.

- [ ] 1. Stock GPT backup + blob inventory (ch.02 S4-S5 ritual; persist/modemst/efs)
- [ ] 2. DT overlay from stock dump (scripts/dump-stock-dt.sh + provenance comments)
- [ ] 3. Defconfig fragment (halide-base + SKU deltas only, ch.03 S11)
- [ ] 4. UART-first boot (no display needed week 1; 115200 8n1 photo hw/<sku>/uart.jpg)
- [ ] 5. Panel + touch week 2 (fastboot boot RAM-only before any flash)
- [ ] 6. Modem-host week 3 (qrtr-lookup -> qmicli -> MM)
- [ ] 7. Container boot_completed week 4 (logs committed)
- [ ] 50-cycle suspend pass (tests/suspend-stress.sh wrapper, logs/suspend.txt)
- [ ] kernel/TECH-DEBT.md entry per out-of-tree quirk (review date set)
- [ ] Branch port/<sku>-w<n> pushed with logs + photos
Stuck-longer-than-3-days escalation: Friday office-hours + bring UART log +
  fastboot-vars.txt + gpt-map.txt (porting-week1-example shape: command ->
  Expected -> gotcha -> fix-with-source).
Trademark: codename internal (REF-x) until neutral public name (ch.11 S24);
  community ports badge COMMUNITY until promoted (ch.02 S14).
