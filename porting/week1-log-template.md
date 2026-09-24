# Week-1 porting log template (porting-week1-example shape: command -> Expected
# -> gotcha -> fix-with-source). Redacted real-shape log; timestamps/IDs
# illustrative, commands exact. Reviewer must reproduce week-1 from this file
# alone on a second unit (annual fresh-eyes test, ch.01 P4 story).

## Day 1 - Backup and inventory (no flashes today)
```bash
TODO-command (e.g. adb shell 'ls -l /dev/block/by-name/' | tee gpt-map.txt)
```
Expected: TODO
Gotcha: TODO
Fix-with-source: TODO

## Day 2 - Defconfig fragment + DT overlay skeleton
```bash
TODO-command
```
Expected: TODO
Gotcha: TODO
Fix-with-source: TODO

## Day 3 - First fastboot boot (no flash - RAM only)
```bash
TODO-command (fastboot boot out/<sku>/boot.img)
```
Expected: TODO (systemd login prompt on UART)
Gotcha: TODO
Fix-with-source: TODO

## Day 4 - Dumps and upstreaming ledger entry
Captured: modetest TODO / qrtr-lookup TODO / regulator summary TODO
TECH-DEBT entry: TODO (link-less TODO with review date per ch.03 S20)
Branch: port/<sku>-w1 pushed with logs + photos: TODO
Week-2 plan (office-hours confirmed): TODO
