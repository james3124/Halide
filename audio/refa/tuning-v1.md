# Audio tuning sheet refa v1 (audio-tuning-sheet.md) - TEMPLATE, no gains ship from this
# Preconditions (all recorded): tinymix.txt SHA TODO | policy.json ver TODO |
# modem FW TODO | speaker/mic HW rev (flex photo + date code) TODO |
# ambient dBA floor (meter model + cal date) TODO | far-end rig (wired ref phone
# in quiet box, model+FW) TODO | acoustic-lab-spec box Leq TODO (empty<=28/loaded<=30)
# Five scripted calls (all 5, every tuning). Each: tinymix diff hunk + far-end
# WAV hash + 3-reviewer blind vote (stock vs tuned vs prev; ties keep prior tune).
# 1 quiet 30dBA earpiece+mic: rx/tx baseline. TODO-measured MOS>=4, floor<=-60dBFS.
# 2 street 65dBA earpiece+mic: tx NR, rx comp. TODO-measured 18/20 sentences, no pumping.
# 3 car 70dBA + BT HFP SCO: ec tail, sco gain. TODO-measured double-talk 10s no howl, echo<=-40dB.
# 4 speakerphone desk: speaker cap (Xmax+thermal datasheet p. TODO) + tx beam. TODO-measured no feedback max, echo<=-40dB.
# 5 headset wired (SKU jack): gain parity +-2dB vs earpiece. TODO-measured L/R + mic match.
# Safety caps: speaker max TODO (datasheet p. TODO) | earpiece 30-min soak TODO |
# boot jingle -6dB below speaker max TODO.
# Sign-off: Audio owner + QA (2-person). Post-merge: measurements.md plots refreshed.
# Status: UNMEASURED - lab takes pending. See audio/lab/noise/README.md hashes.
