# Attack-Test Plan — Proving the Threat Model (red exercises, not vibes)
**Parent: threat-model-stride · Owner: Security + QA · Cadence: per release (subset) + annual full + third-party pentest (08 §18)**

## 1. Container-escape battery (threat-model §4 Elevation — the crown-jewel test)

E1 binder-fuzz storm (malformed transactions at container `ServiceManager` + bridge proxies, 1M iterations corpus from `halide-fuzz-bridges` extended): expect zero host crashes, all rejections structured. E2 mount-namespace breakout attempts (5 published techniques incl. `/proc/self/root` games + symlink races on bind mounts): expect containment (auditd alerts fire, host files untouched — tripwire file `/root/.halide-canary` checked post-test). E3 cgroup-release_agent write attempt (classic escape): expect `neverallow`/cgroupv2 config blocks + alert. E4 one-layer-disabled runs (drop AppArmor, then SELinux-context, then seccomp — ch.08 §4 residual rule): expect remaining layers still hold (documented per-layer hold/miss — a miss is P0, not a footnote). E5 malicious APK battery (10 crafted APKs: overlong intents, billion-laughs XML manifest, permission-confused deputy chains): expect bridge rejections + no host impact + permission split-brain counter stays 0.

## 2. Bridge adversarial suite (threat-model §3 — every socket attacked)

Per socket (`SOCKETS.md` rows): length-lie frames (declare 64KB, send 4 — reader must not over-read), truncation storms, version-downgrade attempts (`proto_v=0` must close, never parse), credential-spoof (connect as wrong UID — `SO_PEERCRED` must reject + log), flood (10× queue depth — drop-newest counters move, signaling intact, memory flat — OOM-kill of the daemon during flood = fail), replay (captured valid frames replayed — sequence/timestamp windows reject). All automated in `tests/adversarial-<bridge>.sh` with PASS = service-healthy-after + counters-match-expected (not merely "didn't crash").

## 3. Bootchain attacks (threat-model §1–2)

B1 old-image boot (rollback drill, appendix-08A §3 — must refuse). B2 tampered-partition boot (flipped bit per 08 §14 — specified panic/EIO behavior observed, not assumed). B3 unlocked-relock dance (relock on wrong key must abort cleanly, 08-A §4 drill). B4 evil-charger USB (charge-only default + no adb + no MTP until unlock+select — ch.08 §10 — tested with hostile-USB fixture: HID-injection + MTP-probe attempts, expect zero host response pre-unlock). B5 cold-boot RAM extraction discussion (documented posture R-3 — test what exists: reboot wipes keys from allocator? verify `init_on_free` + no key material in ramoops after clean reboot — grep drill quarterly).

## 4. Radio-adjacent (threat-model §5 — honest boundaries)

R1 fake-cell fixture (lab callbox advertising wrong MCC): expect roaming prompt + data-off default holds (ch.07 §16), no silent attach (log proves prompt-then-user-decision). R2 modem-crash injection (rproc crash via debugfs on sacrificial unit): expect §15 ladder (queue → restart → reattach → replay-with-confirm). R3 SMS storms (100-part multipart + duplicate retransmits): expect dedupe exactness + no double-send billing events (carrier bill cross-check in lab where possible). R4 OTP interception posture: non-allowlisted package must NOT receive retriever broadcast (negative test — absence proven by instrumented listener).

## 5. Lockscreen bypass session (threat-model §7 — quarterly, QA-led)

5 published bypass patterns attempted (USB-keyboard escape, notification-action deep-link smuggling, overlay tapjacking, camera-from-lock intents, emergency-dial info leak): each recorded PASS (blocked) / FAIL (P0 filed same day + embargo if exploitable per §13 ch.08). New Android-version patterns added to the list within a month of publication (list is living — stale list quarter = process fail assigned to Security).

## 6. Scoring & gating (attacks vote on releases)

Per-release subset (E1-lite 100K iterations + B1/B2 + lockscreen-5 + bridge-flood smoke): any FAIL blocks release (same rank as dogfood P0 — ch.10 §10 taxonomy extended). Annual full + third-party pentest findings enter §15 CVE-bins with SLA clocks (external findings don't get a slower clock — same bins, same escalation). Results published in release-notes security section (counts + bins, sensitive details embargoed per §13 then disclosed — transparency with discipline).

## Verification

- [ ] Per-release subset green with logs; annual full + pentest scoped (pentest-scope.md) with SLA-bound findings; lockscreen-5 quarterly recorded.
