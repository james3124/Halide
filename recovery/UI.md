# UI.md — recovery menu UI (runbook-recovery §1; exact order + wording, screenshots here)
**Owner: Platform + QA · Phase: 2 — button-only navigation on both REF units is a gate**

## Menu (exact order, exact wording)

```
Halide Recovery vX.Y
1. Reboot system now (+ slot: A/B shown, active marked *)
2. Apply update via ADB sideload (same verify+health gates as OTA)
3. Export diagnostic logs (redacted bundle only — auth required if userdata encrypted)
4. Factory reset (crypto-erase + attestation)
5. Switch active slot (shows versions both slots; switching to older warns ROLLBACK but allows with confirm)
6. Power off
```

No shell in release recovery. Volume+power navigation only (touch may be dead when you need recovery).

## Item behaviors

| Item | Confirmation | Notes |
|---|---|---|
| 2 sideload | verify-then-write; bad payload aborts BEFORE writing | progress %, not spinner |
| 3 export | lockscreen PIN required when encrypted (rate-limited); SHA256 shown on screen | bundle = pstore + journal + radio slice, never userdata |
| 4 factory reset | two confirmations + typed SKU → crypto-erase → `WIPE <sku> <ts> <confirm-id>` attestation | wipe-verify per factory/wipe-aql.md |
| 5 slot switch | versions shown; ROLLBACK warn + typed confirm | bootctl state (tries-remaining) displayed — no hidden slot state |

## Screenshots

| screen | file |
|---|---|
| main menu | (capture on REF-A v1.4) |
| wipe confirm + typed SKU | (capture) |
| export SHA screen | (capture) |

Expected: all 6 items navigable button-only; unauthenticated export allowed ONLY for unencrypted-boot-failure case (pstore + versions).

Fail action: sideload writing before verify fails the recovery test (verify-then-write is the gate).
