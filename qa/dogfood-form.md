# Dogfood daily form (ch.10 S10: 2 min, phone-first, 10 testers x 7 days).
# Missed daily = ping; 2 missed = check-in call (silent testers hide gateway bugs).
# Failure taxonomy: P0 (unsolicited reboot, missed MT call/SMS, data detach
# needing manual recovery, thermal shutdown, crypto-erase scare) = gate fail
# immediately; P1 (app crash >2/day, camera miss, GNSS >5min, hotspot drop) = 3+
# across fleet fails gate; P2 (jank, icon, translation) = backlog severity vote.
# Two P0s OR five P1s across 7 days = gate failed, no negotiation.
# CSV columns (header required, consumed by tests/review-sample.py):
# reboots,app_crashes,missed_calls,missed_sms,battery_eod,photos_ok,worst_thing
#
# reboots: count + time (0 required for P0-free day)
# app_crashes: which app (empty = none)
# missed_calls / missed_sms: incoming tally missed vs received
# battery_eod: end-of-day battery percent
# photos_ok: y/n (camera acceptance signal)
# worst_thing: one line, plain words (quoted anonymized in release-compare)
