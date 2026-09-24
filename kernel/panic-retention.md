# panic-retention.md — pstore/ramoops retention policy
**Owner: Kernel (BSP) + Security · Phase: all — crash logs must survive the crash (ch.03 §9/§30)**

## Regions (per-variant addresses in `kernel/devices/<sku>/sku.fragment`, never copied across RAM sizes)

| Backend | File | record_size (min) | Contents |
|---|---|---|---|
| console-ramoops | `/sys/fs/pstore/console-ramoops-0` | 0x20000 | full console ring of the dying boot |
| dmesg-ramoops | `/sys/fs/pstore/dmesg-ramoops-0` | 0x20000 | dmesg frames (modem-active boot >128KB — undersizing truncates the frames that matter) |
| pmsg | `/sys/fs/pstore/pmsg-ramoops-0` | 0x10000 | userspace last-words (bridge crash markers) |
| ftrace | `/sys/fs/pstore/ftrace-ramoops-0` | 0x10000 | suspend-path tracer only (eng) |

`ramoops.mem_address/size/record_size` must match the DT reserved-memory node; mismatch boots but logs `ramoops: disagrees with DT` and boot-lint fails the build (ch.03 §30).

## Retention rule (3 boots)

- pstore files persist across exactly **3 subsequent boots**. `halide-early.service` (ch.05 §2) collects on first boot after crash into `/var/lib/halide/pstore/<boot-id>/` with boot-id linkage; orphans (no boot-id) fail the check.
- Reboot budget: collection happens before the 3rd clean boot overwrites the region. Support script (ch.10 §10) instructs "boot at most twice, then upload" — a 3rd boot may silently destroy evidence.
- Negative tests per release, sacrificial unit: sysrq-c ritual → all four files non-empty; region survives 50-cycle suspend and OTA slot switch; redaction scan greps `BEGIN PRIVATE` + keymaster patterns (any hit = Security P0 — ramoops never carries keying material).

## Redaction rule

Anything leaving the lab passes `halide-log-collect --redact` (IMEI/IMSI/ICCID/MAC/BSSID strip per ch.07 §7). Raw pstore is builder/lab-only; never committed to git, never posted raw (`support/LOG-HOWTO.md`).

Expected: forced sysrq-c then `ls /sys/fs/pstore` shows console-ramoops-0 + dmesg-ramoops-0 + pmsg-ramoops-0 non-empty with the sysrq signature line present.

Fail action: check DT vs cmdline ramoops params + `/proc/iomem` overlap; file BUG against `kernel/devices/<sku>`.
