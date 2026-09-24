# Isolation game-day report -- quarterly (ch.09 S28).
# Plug an office-LAN cable into a staging station + insert a mystery stick;
# selftest must refuse flashing before any unit is touched.
# Refusal-failure = P0 infra bug (runner game-day doctrine). ASCII only.

Date: ____ | Station (staging): ____ | Lead: ____

## Attacks staged
- [ ] Office-LAN cable plugged into station NIC (VLAN bypass attempt).
- [ ] Mystery unlabeled USB stick inserted (evil-stick attempt).
- [ ] SIGN-X ceremony stick presented to station (separation attempt, stick retired after).

## Expected vs actual
| Probe | Expected | Actual |
|---|---|---|
| station-selftest egress probe | FAIL named (office-LAN reachable) + refuse flash | __ |
| USBGuard mystery media | DENY + bin | __ |
| SIGN-X insertion | DENY + alert line lead + stick retired | __ |
| per-unit log isolation header | absent (no unit touched) | __ |

## Result
PASS (refused before any unit touched) / FAIL (P0 filed: ____)

## Prevention item (one per drill, ch.09 S18 close-out doctrine)
- ____

Filed: factory/isolation-drill-____.md  Sign: ____
