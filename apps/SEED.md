# Preinstalled apps — image seed manifest (ch.05 §17, image-size budgeted per ch.09)
# Owner: Platform + Android · Rule: default-app mapping is host-first; Android apps
# never silently become defaults; F-Droid/Aurora preinstalled; no GMS/Play (ch.01 §12).
#
# Each row: id | package | source | drawer | WHY (budget/gate ref)
# Image budget rows counted by scripts/apps-budget.sh (cap per class).

[host-native]
gnome-calls          | org.gnome.Calls       | apt    | host   | dialer single-owner (ch.05 §8)
gnome-chats          | org.gnome.Chats       | apt    | host   | SMS store of record (ril-bridge §12)
epiphany             | org.gnome.Epiphany    | apt    | host   | browser default + portal login window (§29)
gnome-settings       | org.gnome.Settings    | apt    | host   | settings panels + search index source (§23)
gnome-terminal       | org.gnome.Terminal    | apt    | host   | P2 story (ch.01 §11)
libcamera-app        | libcamera-camera-app  | apt    | host   | camera default — host owns camera (ch.04 §8)
gnome-maps           | org.gnome.Maps        | apt    | host   | geoclue+NMEA (ch.07 GNSS path)
halide-backup        | halide-backup         | apt    | host   | backup round-trip suite (ch.05 §19)
phosh                | phosh                 | apt    | host   | home (not a drawer entry; listed for budget)
pipejam              | pipewire wireplumber  | apt    | host   | audio server pair, budget only

[flatpak-filtered]  # remote `halide-filtered`, 20 curated mobile-adapted by Phase-3
# (each graded WORKS/DEGRADED w/ small-screen note; unfiltered Flathub = one-tap add + warning)
flatpak-seed-1 | org.gnome.Polari        | flathub | host | IRC on mobile, small-screen OK
flatpak-seed-2 | com.rafaelcaricio.Decibels | flathub | host | audio player, mobile-adapted
flatpak-seed-3 | org.gnome.Fractal       | flathub | host | matrix client, small-screen note
flatpak-seed-4 | de.haeckerfelix.Shortwave | flathub | host | radio, mobile-adapted
flatpak-seed-5 | io.github.seadve.Mousai | flathub | host | song ID, small-screen OK
flatpak-seed-6 | org.gnome.Snapshot      | flathub | host | camera alt, libcamera backend
flatpak-growth-budget | 14 more rows by Phase-3 | flathub | host | cap 20 total (§17)

[android-system-allowlist]  # seeded in container, drawer-visible with robot badge
F-Droid        | org.fdroid.fdroid      | fdroid | android | store of record, Play-independent
Aurora         | com.aurora.store       | fdroid | android | Play-independent APK source (documented warning)
OpenCamera     | net.sourceforge.opencamera | fdroid | android | container camera app; default stays host (ch.04 §8)
Settings-bridge| com.android.settings  | aosp   | android | bridged intents via settings/ANDROID-INTENTS.csv

[drawer-hidden]  # installed but hidden (ch.05 §13 hide.conf) — duplicates of host apps
stock-dialer | com.android.dialer    | aosp | hidden | dual-dialer confusion ban (ch.05 §8)
stock-sms    | com.android.messaging | aosp | hidden | Chats is store of record
stock-browser| com.android.browser   | aosp | hidden | Epiphany is browser default

# MicroG: explicitly NOT preinstalled (documented sideload only — ch.01 §12 legal posture)
# No own app store (ch.01 §4 non-goal). Default-app mapping table: apps/DEFAULT-APPS.csv
