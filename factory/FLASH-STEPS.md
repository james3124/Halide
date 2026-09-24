# Factory flash steps (PLAN-ONLY, never execute on phone here)
1. Confirm EVT unit label from hw/refa/inventory.md.
2. Verify host has halide-<device>-<slot>.img names per images/README.
3. Boot device to fastboot; confirm serial matches label.
4. Flash slots per program/DEPLOY-CHECKLIST.md order only.
5. Verify AVB per security/avb-policy.txt before handoff.
6. Log result; never run flash from this repo shell.
7. Technician sign-off + date required; text plan only, no binaries executed.
