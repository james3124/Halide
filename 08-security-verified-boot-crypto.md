# 08 — Security: Verified Boot, Encryption, SELinux+AppArmor
**Budget: 70,000 chars · All phases · Owner: Security · Rule: no silent downgrades**

## 1. Threat model (v1 scope)

Attackers: stolen-device reader, malicious app (either stack), malicious base-station-adjacent network, evil-charger USB. Out of scope v1: state-level baseband RCE containment beyond modem isolation, side-channels, Play Integrity spoofing. State assumptions plainly in release notes.

## 2. Verified boot chain (AVB, enforcing for Phase 3)

PBL→XBL→ABL→`vbmeta`→`boot`/`vendor_boot`→`super` (dm-verity hash trees) → systemd (verity `root_hash` cmdline) → container (verity). Keys: per-release RSA4096 in HSM/offline (`keys/` holds pub + metadata only, never private in git).

```bash
avbtool make_vbmeta_image --output vbmeta.img --key keys/release_pub.key \
  --algorithm SHA256_RSA4096 --flag 2 --rollback_index $BUILD_NUM \
  --include_descriptors_from_image boot.img \
  --include_descriptors_from_image vendor_boot.img
```

States: green (locked+verified) required for daily-driver; orange/yellow dev-only with persistent warning + `ro.boot.verifiedbootstate` visible in About. Rollback protection: index bump every release; test old-image refusal quarterly.

## 3. Encryption at rest

Host: LUKS2 (AES-256-XTS, Argon2id) for `/userdata` with lockscreen-bound passphrase (GNOME keyring-equivalent unlock at Phosh lock). Android container data (`/data/android`) inside same LUKS volume (no double encryption v1) + per-file keys for app sandbox where AOSP file-based encryption available. Factory reset = crypto-erase (discard data key) + verifiable wipe log.

First-boot: force PIN ≥6 + auto-encrypt (no "skip"); recovery requires auth to export logs (redacted bundle only).

## 4. MAC: SELinux (Android) + AppArmor (host) coexistence

- Android processes stay under SELinux `enforcing` with AOSP+device policy; host processes under AppArmor (`halide-android`, `halide-bridges`, `halide-composer` profiles in `security/apparmor/`).
- Container boundary: LXC + SELinux context `u:r:container:s0` + AppArmor + seccomp-bpf (both layers; removing one must still leave one enforcing — test by disabling each in harness, never on user builds).
- Every `audit2allow`/profile exception: comment with bug ID + expiry + test ID. Quarterly `avc: denied` diff vs baseline; new denials block release.

Bridges are the attack surface: each socket in `bridges/SOCKETS.md` gets a mini-review (who can connect, what parsing, fuzz harness link). `halide-fuzz-bridges` runs in CI (libFuzzer on parsers, 10 min smoke per MR).

## 5. Updates & keys

Release signing (offline): kernel+boot+super+OTA payload signed; `update_engine` verifies before slot switch. Key rotation runbook: dual-sign transition release N, revoke at N+2, with user-visible "security update" prompt. Compromise plan: revocation OTA + public advisory template in repo.

## 6. App sandbox & permissions

Single consent → both stacks (ch.05 §4). No silent permission inheritance: Android `READ_SMS` grant does not grant host address-book unless user also approves host prompt (explicit mapping table in Settings → Privacy). Network permission per-app enforced at host nftables by UID mark (so Android VPN/Firewall claims are actually true).

## 8. Key management & signing ceremony (normative)

Key hierarchy: offline root (HSM or air-gapped USB, RSA4096) → per-product release key → per-SKU AVB key + OTA key (rotation independent so one SKU compromise doesn't reissue the fleet). `keys/` in git holds ONLY `.x509.pem` pubs + `key-metadata.json` (algorithm, creation date, rotation due, custodian initials — never private bytes; CI fails the build if a `PRIVATE KEY` PEM block is detected).

Ceremony (quarterly or per release, two custodians, logged): (1) verify builder `hashes.txt` SHAs on offline machine, (2) sign boot/vendor_boot/super/vbmeta + OTA payload, (3) write `signatures.json` (artifact, signer id, timestamp, rollback index), (4) transparency entry (append-only log file committed to a separate `halide-transparency` repo), (5) publish pubs if rotated. Dual-sign rotation: release N ships old+new pubs (devices accept both), N+1 signs with new only, N+2 drops old — devices that skipped N..N+1 get a full-image (not delta) re-key path, documented.

Compromise runbook: revoke key id in transparency log → emergency OTA signed by root (not the compromised subkey) → public advisory from template `security/ADVISORY-TEMPLATE.md` (CVE-style: affected versions, impact, action, verification command the user can run: `avbtool info_image --image vbmeta.img | grep -i key`). Recovery drill annually on VIRT (rotate test keys end-to-end, measure user-visible friction).

## 9. Encryption operations detail

LUKS2 parameters (binding): `aes-xts-plain64`, 512-bit key, `argon2id` (time=4, memory=1GB capped for mobile SoC — measure unlock latency ≤3s on REF-A slow cores; record per SKU), `pbkdf` + token-bound to lockscreen PIN via `halide-pin-derive` (PIN≥6, rate-limited: 10 wrong → 30s delay doubling, + wipe-offer at 30 — enterprise P3 can set wipe-at-N policy). `cryptsetup luksDump` archived per release (keyslot count = 1 + recovery-escrow slot only where enterprise policy demands, never a universal backdoor slot).

Container data: `/data/android` bind-mounted from `/userdata/android` inside the same LUKS volume (single passphrase prompt at Phosh lock — two prompts is a UX fail and a support burden). AOSP file-based encryption keys for app sandbox are wrapped by the LUKS-unlocked keyring (document key flow diagram in `security/key-flow.dot`: PIN → KDF → LUKS → volume key → FBE master → per-app keys).

Suspend-to-RAM keeps keys in memory (standard mobile posture — state it, don't hide it); Evil-maid mitigations documented as limits (verified boot detects tampered boot, not RAM extraction — honest scope, ch.01 threat model referenced).

Crypto-erase (factory reset): `cryptsetup erase` data keyslot + `blkdiscard` userdata + new filesystem UUIDs + wipe attestation line (`WIPE <sku> <timestamp> <operator-confirm-id>`) in recovery log. Verification: post-wipe `hexdump` sample of userdata shows no LUKS header + no plaintext strings from pre-wipe canary file (`CANARY-<random>` written pre-wipe, searched post-wipe — canary absent = pass).

## 10. AppArmor profiles + seccomp + nftables (host enforcement)

Profiles (`security/apparmor/`): `halide-android` (lxc-start + container helpers: allow binderfs/dri/snd binds, deny raw `persist`/`efs` block writes, deny `ptrace` outside container), `halide-bridges` (per-bridge socket paths from SOCKETS.md encoded as rules — a socket not in the profile can't be bound even if code tries), `halide-composer` (dri + wayland socket + input socket only). `aa-status` enforcing on all three is a release gate; `complain`-mode stragglers block.

Seccomp-bpf per bridge (`security/seccomp/<bridge>.json`): allowlist syscalls for event-loop + socket + binder-ioctl families; `execve` denied in bridges (no shell-out from parsers — RCE containment), `ptrace` denied. Fuzz corpus from `halide-fuzz-bridges` (libFuzzer harnesses on every socket parser + protobuf/JSON decoder; 10-min smoke per MR, 4h nightly; crash = P0 + regression seed committed).

nftables baseline (`security/nftables.conf` committed): default-deny forwarded traffic from container except via bridge-approved marks; per-app UID-mark rules for Android VPN/firewall claims (so "block app X" in UI = real `nft` drop rule with counter; test toggles rule counter increments). VPN kill-switch: when host VPN with kill-switch is on, container egress without VPN mark is dropped (leak test: `curl` from container during VPN flap must fail closed — automated in `tests/vpn-leak.sh`).

USB attack surface (evil-charger): default USB mode = charging-only (no ADB/MTP until user unlocks + selects in notification — host-side `USB_MODE` state machine; Android gadget follows host, never exposes independently). `adb` authorized-keys model (host `~/.android/adbkey` equivalent + on-device fingerprint confirm); eng builds still require confirm (no open adb, ever — CI greps `ro.adb.secure=0` as fail).

## 11. Patch SLA & vulnerability operations

Monthly cadence: Android SPL + kernel LTS stable + Debian security pocket merged within 30 days of upstream (60-day absolute gate from ch.01). `cvecheck` equivalent per release: kernel CVE scan (stable-queue lag list), AOSP bulletin delta, `debsecan` for host — all three attached to release notes with disposition per CVE (patched / not-affected-with-reason / mitigated-by-config + test). Stale-patch dashboard (`security/PATCH-STATUS.md`) updated weekly during dogfood; red entries (>45 days) escalate to Arch.

Bug handling: `SECURITY.md` (report channel, PGP, 90-day disclosure default), severity rubric (RCE-as-root / verified-boot bypass / lockscreen bypass / modem-data leak tiers with response times), embargo branch procedure, post-fix retrospective template.

## 12. Incident drills (rehearsed annually, tabletop + live-fire mix)

Tabletop (all leads, 90 min): scenarioRotation — (a) malicious bridge-parser RCE report (ch.05 §10 socket threat notes become the playbook), (b) signing-subkey compromise (ch.08 §8 revocation OTA path walked click-by-click), (c) modem-driven data exfiltration claim (QRTR audit + nftables counters as evidence tools), (d) stolen dogfood unit with pre-patch build (remote-wipe + transparency-log forensics). Each drill produces 3 action items max (more = none get done) tracked to closure before the next drill. Live-fire (lab, scheduled): red-team night — eng build with planted vuln (known CVE reintroduced in sandbox branch), blue team must detect via fuzz/CI + patch + advisory-draft within the SLA clock (ch.08 §11 rubric timed live). Drill reports live in `security/drills/<date>.md` (what worked, what was slow, what lied — dashboards that lied get fixed first).

## 13. Embargo handling (90-day default per SECURITY.md, with teeth)

Embargo branch: separate repo (not a hidden branch in the public one — history leaks), access list = fix owner + Security + one QA + release-button-holder (4 people, named per incident, access revoked post-ship automatically). Test builds from embargo branch carry `EMBARGO-<id>` watermark + 7-day expiry (ch.09 §12 nightly-expiry machinery reused — leak of an embargo build is time-boxed by construction). Pre-notification (T-7 days): blessed-carrier security contacts + enterprise P3 fleet admins under embargo (their patch-window needs are the reason, not courtesy). Disclosure day: fix + advisory + CVE (if applicable) + dogfood fast-track OTA + retrospective scheduled (blameless template, ch.11 risk-review input). Embargo-break (leak) procedure: immediate full-disclosure (no partial — partials arm attackers without helping defenders) + compress remaining timeline to 48h + postmortem on the break itself.

## 14. dm-verity hash-tree operations (the part everyone configures once and debugs forever)

Per-partition hashtree descriptors (`avbtool add_hashtree_footer --partition_name system --partition_size <exact> --hash_algorithm sha256 --block_size 4096 --salt <per-release-random-hex>`): salt regenerated per release (same-salt-across-releases enables cross-version block-correlation analysis — cheap to rotate, so rotate), FEC (`--do_not_generate_fec` default-off decision per SKU in appendix-08A/B with wear math: FEC costs ~1–3% partition + write amplification; enable where UFS error stats justify, document where not). Corruption behavior specified, not discovered: single-bit rot in `system` → I/O error on that block + `dm-verity` device `restart-on-corruption`? NO — v1 policy is `panic-on-corruption` for boot-critical partitions (fail visibly at boot, not mysteriously at runtime) and `EIO-to-app` for higher-level partitions (app crash with verity tag in tombstone, not system wedge). Both paths demonstrated quarterly on sacrificial unit (`dd` a flipped bit into inactive slot → boot it → assert the specified behavior, log the test — untested corruption handling is fiction).

`adb`-visible verity state: `adb shell getprop ro.boot.veritymode` + `dumpsys` marker in Settings → About (tapping shows hash algorithm + salt date — auditability the user can screenshot to support). Verity-disabled eng builds watermark the boot splash diagonally ("VERITY OFF — eng") so screenshots from eng builds can never be mistaken for release posture in bug reports.

## 15. CVE triage workflow (ch.08 §11 SLA made executable — 30/60-day clocks with names)

Intake (weekly, Security owner, 30 min): sources — kernel stable-queue (`stable@vger` review for our LTS), AOSP monthly bulletin (applicability per our manifest revision — bulletin items for code we don't ship get `NOT-AFFECTED:<reason>` same week, not left open), `debsecan` host report, firmware vendor advisories (where obtainable; unobtainable-vendor-advisory is itself a risk-register line per SKU). Triage bins with clocks: `PATCH-NOW` (exploitable-in-our-config remote or lockscreen-bypass — lands ≤7 days, hotfix train ch.09 §3), `PATCH-TRAIN` (monthly, ≤30 days), `MITIGATED` (config already blocks — proof attached: which neverallow/seccomp/nft rule + test demonstrating the block, re-verified per release), `NOT-AFFECTED` (one-line mechanism reason + version evidence). Stale-bin rule: item older than its clock without disposition change escalates to Arch review automatically (bot-filed `ESCALATE` issue — clocks without escalation are wishes).

Disposition record (`security/CVE-<Y>-<NNN>.md` per item or per-bulletin batch): upstream refs, our-config analysis, chosen bin + rationale, fix commit or mitigation proof, verification (which test demonstrates patched/blocked), release-notes line (ch.09 §14 CVE section consumes these files — notes generated from records, not memory).

## 16. Kernel self-protection (exploitation made expensive — defense in depth, all on)

Config fragment `kernel/halide-hardening.fragment` (merged after base, ch.03 §3 order — hardening never accidentally overridden by SKU fragments; CI asserts final `.config` contains every line below):

```
CONFIG_KASLR=y
CONFIG_RANDOMIZE_BASE=y
CONFIG_RANDOMIZE_MODULE_REGION_FULL=y
CONFIG_STACKPROTECTOR_STRONG=y
CONFIG_SCHED_STACK_END_CHECK=y
CONFIG_VMAP_STACK=y
CONFIG_THREAD_INFO_IN_TASK=y
CONFIG_REFCOUNT_FULL=y
CONFIG_HARDENED_USERCOPY=y
CONFIG_FORTIFY_SOURCE=y
CONFIG_UBSAN_BOUNDS=y
CONFIG_UBSAN_MISC=y                   # trim per perf measurement (§17) — never silently
CONFIG_INIT_ON_ALLOC_DEFAULT_ON=y
CONFIG_INIT_ON_FREE_DEFAULT_ON=y
CONFIG_PAGE_POISONING=y (or init_on_free Poison where mutually exclusive — record choice)
CONFIG_SLAB_FREELIST_HARDENED=y
CONFIG_SLAB_FREELIST_RANDOM=y
CONFIG_SHUFFLE_PAGE_ALLOCATOR=y
CONFIG_RANDOM_KMALLOC_CACHES=y
CONFIG_SECURITY_DMESG_RESTRICT=y       # dmesg needs privilege (info-leak closure)
CONFIG_DEBUG_WX=y
CONFIG_STRICT_KERNEL_RWX=y
CONFIG_STRICT_MODULE_RWX=y
CONFIG_KPROBES=n (release; userdebug-gated eng only — live-patch surface closed)
CONFIG_BPF_JIT_ALWAYS_ON=y + CONFIG_BPF_UNPRIV_DEFAULT_OFF=y  # unpriv eBPF off (container escape vector closed)
CONFIG_SECCOMP_FILTER=y (already base) + CONFIG_SECCOMP_CACHE_DEBUG=n
CONFIG_STATIC_USERMODEHELPER=y + PATH=empty (usermode-helper escape closed)
CONFIG_KEXEC=n + CONFIG_KEXEC_FILE=n (release — cold-boot attack + rootkit persistence vector closed; eng-only)
CONFIG_HIBERNATION=n (no swap-resume key exposure; suspend-to-RAM posture ch.08 §9 stands documented)
CONFIG_LDISC_AUTOLOAD=n (line-discipline RCE class closed)
CONFIG_MODULE_SIG_FORCE=y (release) + KEYRING (ch.09 signing chain)
```

ARM64 control-flow: `CONFIG_CFI_CLANG=y` (KCFI, forward-edge) + `CONFIG_SHADOW_CALL_STACK=y` (backward-edge) where LLVM+GKI support on our LTS (verify per toolchain pin — if either unsupported on the pinned clang, the release is blocked until toolchain bump, not shipped without; the gate is written here so schedule pressure can't waive it). `rodata=full`, `init_on_free`, KASLR entropy check at boot (`kaslr-seed` from bootloader/HWRNG — zero-entropy-seed boot emits `KASLR_NO_SEED` alert + blocks release promotion; debug `nokaslr` cmdline grepped-and-rejected in release images by CI).

Perf honesty: each mitigation's cost measured once per SKU (`lmbench` + boot-time delta table in `security/mitigation-cost.md`); a mitigation may only be disabled for perf with (a) measurement proving >5% user-visible regression, (b) compensating control named, (c) Arch + Security dual sign, (d) expiry review — the four-part waiver committed in-tree (waivers without expiry are holes with paperwork).

## 17. Memory-safety direction (the only durable vuln-rate reducer)

New userspace attack-surface code (bridges, composer, daemons) is Rust or Go (ch.05 §9 already mandates no-Python-hot-path; extend: no new C parsers on any socket — existing C parsers get a Rust rewrite tracked in TECH-DEBT with dates). Kernel: Rust-for-Linux enabled where our LTS supports (`CONFIG_RUST=y` evaluated per LTS bump — new drivers prefer Rust bindings; unsafe blocks require safety-comment + second reviewer). Fuzzing is continuous (ch.08 §10: 10-min MR smoke + 4h nightly + corpus committed; coverage trend dashboarded — coverage drops page the area owner). SAST in CI: `clang-analyzer` + `CodeQL` (or Semgrep ruleset) on C/C++, `cargo clippy::all + deny(warnings)` + `cargo audit`, `govet + staticcheck + govulncheck` — new HIGH/CRITICAL finding blocks merge (no "fix later" tag for vulns — later never comes).

## 18. Disclosure, bounty & no-known-vuln shipping rule (your requirement, formalized)

`SECURITY.md` (repo root + website): report PGP key + response SLA (triage 48h, fix-clock per §15 bins, credit offered). Shipping rule (binding): no release ships with a KNOWN-unpatched HIGH/CRITICAL in our config — either patched, proven-mitigated (§15 `MITIGATED` with test), or the release doesn't ship (the rule outranks dates; dates move, holes don't). Coordinated disclosure default 90-day (ch.08 §13 embargo machinery); reporter gets fix-verification build pre-release on request. Bounty posture v1: no cash bounty (say so plainly + what exists instead: credit wall, fast triage SLA, researcher-friendly debug builds `halide-research` with symbols + `KASAN` userdebug variant for vuln hunters — making researchers effective beats pretending a bounty). Annual third-party pentest from Phase-3 (scope file: `security/pentest-scope.md` — bootloader, bridges, OTA, lockscreen, container escape, modem-data path; findings SLA-bound like internal vulns).

## 19. HSM & offline-signer operations (the room where trust lives)

Signer machine spec (committed in `keys/signer-spec.md`): air-gapped (no Wi-Fi/BT hardware present — physically absent, not disabled; Ethernet port epoxied with photo in spec — theater that works), Debian stable minimal + pinned packages (same digest-pinning as builders, ch.09 §7), full-disk encrypted (passphrase split 2-of-3 Shamir among custodians — no single person can decrypt alone, ceremony quorum ch.08 §8 extends to disk), USB data diode practice (single-purpose SIGN-X sticks, scanned both sides, retired annually). Key generation ceremony (once per key, witnessed): HWRNG-seeded RSA4096 on the signer (never generated online — generation transcript signed by witnesses, stored with ceremony logs ch.09 §15), pub exported + fingerprint read aloud + recorded (verbal check defeats file-swap, same doctrine as signing ceremony), backup to second encrypted medium stored off-site (sealed envelope with tamper tape, serial logged — envelope inspection annual ritual with photo). Custodian roster (`keys/custodians.md`: 3 named, quorum any-2, stand-in drill annual per ch.11 risk-12 mitigation — drill uses the Shamir shares, not passwords, so the split actually gets exercised). Compromise-or-loss of a share: re-split ceremony within 30 days (2 remaining shares suffice — that's the point of 2-of-3; re-split restores the safety margin, incident logged even though unexploited).

## 20. Lockscreen attempt-limit UX detail (rate-limiting the attacker without bricking the owner)

Binding parameters (host Phosh lock + LUKS derive `halide-pin-derive`, consistent with §9): PIN ≥6 enforced at first-boot (§3) and at every PIN change (Settings → Security → Change PIN: rejects <6, rejects 123456/000000/birth-year-trivial list of 50 documented in `security/weak-pins.txt`, rejects repetition of current PIN). Attempt accounting survives reboot (counter in tamper-evident host state under `/userdata/.halide/lockstate`, fsync per attempt — power-pull during guessing must not reset the count).

Escalation ladder (exact, user-visible strings committed so support and docs match):
1. Attempts 1–5: no delay. Message: "Wrong PIN. N attempts remaining before delay." (N = 10 − count; honest countdown, no scare offset.)
2. Attempt 10: 30s delay (timer enforced in the unlock daemon, not the UI — killing Phosh doesn't skip it). Message with live countdown + "Emergency call still available" (emergency path never gated — regulatory, §7-adjacent telephony rule).
3. Attempts 11+: delay doubles per failure (30s → 60s → 120s … capped at 15 min). Message names the wait + offers "Forgot PIN? Recovery options" (recovery = authenticated backup/restore path, never a bypass — support script states this verbatim so social-engineering callers can't shop for a softer answer).
4. Attempt 30: wipe-offer screen (not auto-wipe v1 — auto-wipe is enterprise-P3 opt-in `wipe-at-N` policy only). Offer text: "30 wrong attempts. Erase this device to protect your data? [Erase] [Keep trying]". Erase requires typing `ERASE` + PIN-length confirm (pocket-tap can't wipe).
5. Enterprise P3 `wipe-at-N` (MDM-set, N ≥10, recorded in `security/policy-<fleet>.md`): at N the device crypto-erases per §9 flow + writes wipe attestation. Fleet admin + user both notified pre-enrolment (no surprise wipes — consent text committed).

Anti-footgun rules: delay timer pauses (not resets) on reboot; biometric (where present, out-of-v1-scope per §1 — placeholder) never resets the PIN counter; container-side Android lock is slaved to host verdict (Android keyguard unlock without host unlock = rejected + logged — single lock authority, mirrors §4 single-consent direction table). Testing: `tests/lockscreen-5.sh` (attack-test-plan §5 harness): scripted 12-wrong-PIN run asserting delays at 10/11/12 + reboot-persistence + emergency-dial reachable + wipe-offer absent before 30; annual lockscreen-bypass session (ch.11 §15 calendar) runs the full 30-attempt + enterprise-wipe path on a sacrificial unit.

## 21. Wipe-verify procedure ops (erase must be provable, not promised)

Trigger paths: user factory-reset (Settings → System → Erase, typed confirm), recovery factory-reset (auth-gated per §3), enterprise remote-wipe (P3 fleet), lockscreen wipe-at-N (§20). All paths converge on one implementation `halide-wipe --verify` (no per-path erase logic — divergent erase paths are how "wiped" devices keep photos).

Procedure (ordered, logged to recovery log + attestation line per §9):
1. Pre-wipe canary: write `CANARY-<32-hex>` to 3 userdata locations (file, sqlite row in Chats-layout scratch, raw offset note) + record LUKS header SHA.
2. Unmount userdata + kill container (no live writers during erase — open FDs are how blocks survive discard).
3. `cryptsetup erase <data-keyslot>` + `blkdiscard -f userdata` + new filesystem UUIDs + regenerate LUKS header (new salt — old header image useless).
4. Post-wipe verify (blocking, not advisory): re-read LUKS header region (must differ from recorded SHA + must not decrypt with old wrapped key — attempt-and-fail logged), `hexdump` sample 3× 64MB windows searched for canary string (absent = pass), `blkid` shows new UUIDs. Any verify miss → `WIPE-VERIFY-FAIL` state (device refuses first-boot setup, shows "Erase incomplete — retry" + support code; retry allowed ×3, then RMA-quarantine per factory runbook — a half-wiped device must never look clean).
5. Attestation: `WIPE <sku> <timestamp> <operator-confirm-id> <verify:PASS> <header-sha-new>` appended to recovery log + QR-printable on factory station (ch.09 §16 log format extended). Enterprise fleets get attestation upload (MDM receipt).

Operator drill: quarterly wipe-verify on sacrificial unit (QA owns calendar entry ch.11 §15): run full path, confirm canary-absent + header-rotated + attestation present, file `security/wipe-drill-<date>.md` (pass/fail + hexdump sample hashes). Failed drill = P0 (erase is the last promise — it doesn't get "known issue" status).

## 22. Researcher-build distribution policy (make hunters effective without arming thieves)

Build flavors (exact): `halide-research` = userdebug + symbols + `KASAN` kernel variant where REF supports it (ch.03 §21 KASAN gate) + `VERITY OFF` diagonal watermark (§14) + nightly-expiry machinery (ch.09 §12, 30-day) + `ro.adb.secure=1` still enforced (researcher convenience never disables auth — §10 USB rule stands). Research builds are signed with a dedicated `research` key (never the release key — `avbtool info` greps distinguish; release-key-on-research = compromise drill ch.08 §8).

Eligibility: public request via `SECURITY.md` channel (name/handle + PGP + intended scope + agreement to 90-day coordinated disclosure §13). Approval: Security owner + one lead, SLA 5 business days, decision logged (`security/researchers.md`: handle, scope, build version, expiry — access list hygiene, same discipline as embargo §13). No NDA required for vuln disclosure (NDAs chill reporting; embargo mechanics already protect the window).

Distribution: time-boxed download link (7-day) + per-recipient watermark (build id encodes recipient hash — leaked build attribution without PII in-image) + scope note (which SKU/firmware the build matches). Builds expire per ch.09 §12 (expired research build = host-alive/data-recoverable, container-halted — same as nightlies). Findings intake follows §15 bins with `PATCH-NOW` fast-track for researcher-reported lockscreen/verified-boot bypass (triage 48h per §18 SLA + reporter gets fix-verification build pre-release on request).

Abuse handling: leaked research build used in the wild → rotate research key + shorten expiry to 14 days for next cycle + postmortem (not researcher-blaming by default — investigate distribution-list hygiene first). Annual review: researcher count, vulns found via research builds vs internal, MTTR on researcher reports (metric in ch.11 §11 security set).

## 23. Supply-chain threat rows for each new dependency class (STRIDE-per-input, not vibes)

Parent: threat-model-stride doc + ch.09 §13 digest-pinning. Each row: dependency class → threats (S/T/R/I/D/E) → control (where in plan) → residual + review trigger. New classes introduced by §§20–22 and recent plan growth:

| Dependency class | Key threats | Control (binding ref) | Residual / review trigger |
|---|---|---|---|
| Modem-fw blobs (ch.07 §23) | T: trojaned fw image; E: fw parser RCE via QMI; R: vendor denies issue | SHA + vendor-note archived; sacrificial-first + re-bless; QMI fuzz corpus | Residual: closed fw, behavioral attestation only. Trigger: vendor advisory or stall-regression → P0 |
| Connectivity-check / probe endpoints (§20, NM) | S: captive-portal spoof; I: probe metadata (timing/cell); T: DNS hijack | Allowlisted URI + HTTPS; probe marked + logged; DNS-fallback logged | Residual: network observer sees probe timing. Trigger: endpoint cert change → hold + verify |
| MBPI + carrier APN pushes (§21) | T: malicious APN (traffic reroute); R: carrier repudiates push | Pin + staging (no auto-promote); authenticated-push-only accept | Residual: stale APN DoS. Trigger: >5 fallback/month → DB review |
| Research-build recipients (§22) | I: leaked build aids exploit dev; R: researcher doxxing via watermark | Per-recipient watermark (hash, no PII); research-key separation; expiry | Residual: determined actor extracts vuln. Trigger: leak → rotate + shorten expiry |
| Factory-station laptop + USB sticks (ch.09 §§15–16) | T: infected station flashes malware; E: evil SIGN-X stick | Pinned station image + scanned single-purpose sticks; per-partition verify-after-write | Residual: physical access = game over (stated). Trigger: hash mismatch → freeze + ch.09 §13 runbook |
| Transparency repo + mirrors (ch.09 §17) | T: mirror serves mismatched bytes; R: history rewrite | Append-only + force-push disabled; user verify procedure (hash + avbtool + rollback) | Residual: user skips verify. Trigger: mirror complaint → canonical-hash check within 24h |
| HSM/signer media + Shamir shares (§19) | I: share theft; D: quorum unavailable at release | 2-of-3 split, sealed off-site backup, annual stand-in drill | Residual: coercion (out of scope, stated). Trigger: ceremony delay >2w → ch.11 risk-12 |
| Power meters / lab calibration (ch.10 §8) | T: miscalibrated meter fakes power gate; R: unlogged ambient | Per-unit calibration.md + footnote lint; 3-run same-ambient rule | Residual: ±5% meter lie (documented). Trigger: calibration age >1y → renew (ch.11 §15) |

Each row has an owner (Security + area lead) and a re-review date (quarterly for modem-fw/carrier, annually otherwise — dates in `security/supply-chain-review.md`).

## 24. Annual control-effectiveness review (does any of this actually work)

Week-long review every 12 months (owner Security, attendees all leads + QA): for each control family (verified-boot chain §2, LUKS ops §9, AppArmor/seccomp/nft §10, patch SLA §11, CVE triage §15, kernel hardening §16, lockscreen §20, wipe-verify §21, researcher builds §22, supply-chain §23) answer with evidence: (a) control operated? (logs/ceremony/dashboards linked), (b) control caught anything? (counts: denials, fuzz crashes, quarantine hits, drill halts), (c) control cost? (build-time, triage-hours, user friction), (d) verdict: KEEP / TUNE / RETIRE-with-replacement (retire without replacement requires Arch + Security dual sign + ADR entry ch.11 §14).

Inputs assembled beforehand (no live hunting during review week): fuzz-coverage trend + MTTR (§17 metrics), patch-lag histogram (§11), embargo/wrong-key drill reports (§§8/13), wipe + lockscreen drill logs (§§20–21), transparency completeness (% releases with full dirs, ch.09 §17), researcher-build stats (§22). Output: `security/control-review-<year>.md` (per-family verdict + 3 action items max carried to next quarter OKRs ch.11 §12 — more = none get done, same rule as §12 drills) + risk-register delta proposed to Program (ch.11 §§3/13 updated from findings, not from memory).

## 25. Pentest intake, findings SLA & retest discipline (Phase-3 onward, scope-committed)

Scope file `security/pentest-scope.md` (frozen 2 weeks before test start — scope creep mid-test invalidates the bid): bootloader/AVB chain (§2, incl. rollback-refusal + eng-watermark distinguishability §14), bridge sockets (SOCKETS.md top-5 by exposure + 1 tester-choice parser), OTA verify+health path (ch.09 §§4/9 — downgrade, slot-confusion, sideload-bypass attempts), lockscreen ladder (§20 full 30-attempt + enterprise wipe-at-N on sacrificial unit), container-escape (LXC+SELinux+AppArmor+seccomp layering §4 — tester gets userdebug + one unprivileged container shell, nothing else), modem-data path (APN-push handling §21 ch.07, probe/DNS behavior §20 ch.07 — tester gets malicious-carrier fixture, not live network abuse). Explicitly out (stated so the report can't claim it): baseband RCE containment beyond isolation (§1 out-of-scope), side-channels, Play Integrity, social-engineering of custodians (tested by drill §19 stand-in exercise instead).

Rules of engagement: lab sacrificial units only (IMEI redacted in report, photos of PCB allowed only with Program sign), no testing of carrier live networks (callbox/RF-shield fixture provided + packet captures), no disclosure of embargo-branch-adjacent findings outside the §13 channel (pen-testers join the 4-person embargo list for their own findings only). Deliverable: findings with CVSS + our-config exploitability note (tester states which of our mitigations §16 blocked or failed — "bypassed KCFI" vs "stopped by seccomp" changes the bin), PoC that becomes a regression test (same doctrine as incident-response runbook: every finding leaves a net), retest window included in the bid (fix verification ≤30 days post-report, same engineers, no re-scoping fee).

Findings SLA (same bins as §15, clock starts at report delivery): critical (verified-boot bypass, lockscreen bypass, container→host escape, RCE-as-root) = PATCH-NOW ≤7 days + hotfix-lane candidate (ch.09 §21 entry criterion met by definition); high = PATCH-TRAIN ≤30 days; medium/low = next train ≤90 days with compensating-control note if deferred. Retest: all critical/high re-verified by the tester (not self-certified — self-graded pentests are marketing); missed-SLA finding escalates to Arch with the §15 bot-filed ESCALATE issue. Report handling: full report in `security/pentest-<year>.md` (redacted for distribution — tester PII + sacrificial-unit identifiers stripped), executive summary in release notes where user-actionable (otherwise "third-party assessment completed, N critical fixed" + advisory links — honesty without arming).

## 26. Secure-element / StrongBox future staging (what v1 prepares without claiming)

v1 posture (binding, no-GMS §1-adjacent honesty): no StrongBox security-level claim, no tamper-resistant keystore claim, no payment-grade promise. v1 keys live in the §9 LUKS→FBE hierarchy (software-wrapped, verified-boot-bound) and `ro.hardware.keystore` reports `software`/`tee`-only where actually backed (never `strongbox` — a false StrongBox attestation breaks enterprise MDM trust permanently once discovered; the property value is a release-gate assert in `tests/keystore-level.sh`). What v1 DOES build so Phase-4 StrongBox/SE doesn't require re-architecture:

1. Keystore HAL abstraction owns a `security_level` enum from day one (`Software < TEE < StrongBox`, AOSP `KeyMint` tags passed through the bridge unmapped — no v1 code path assumes `Software==TEE`; bridge schema `key_attest` carries `security_level + attestation_chain[]` fields populated truthfully even while always-Software, so Phase-4 issuers don't change the wire format, only the values).
2. Key alias namespacing reserves `hb_strongbox_` prefix (any v1 request for that prefix returns `ATTESTATION_IMPOSSIBLE_V1` with docs link — explicit refusal beats silent software-fallback that a future auditor mistakes for hardware backing).
3. Verified-boot binding recorded per key (`verifiedbootstate-at-creation` + rollback-index stored alongside the §9 key-flow diagram — Phase-4 SE keys will additionally bind to `vbmeta` digest; v1 stores the digest field already so migration is additive).
4. Threat-model row pre-added (§23 table extended at Phase-4 kickoff, placeholder entry committed now): `Discrete-SE / eSE` class with threats S/T/I/R mapped to controls TBD — the row exists as `DEFERRED-PHASE4` so nobody ships SE-dependent features (passkeys-sync, car-key, payment) on v1 software keys by accident; each such feature MR must cite this section and is rejected pre-Phase-4.
5. Hardware.inventory per SKU (`hw/<sku>/se-presence.md`): eSE/NFC-SE/embedded-UICC-secure-domain presence recorded during REF bring-up even though unused (same discipline as ch.07 §19 eUICC presence note — presence noted, capability unclaimed).

Phase-4 entry criteria (gates, not dates): discrete-SE driver + HAL wired on at least one SKU, third-party lab tamper evaluation scoped, `security_level=StrongBox` attested end-to-end on sacrificial units with the §25 pentest scope extended (key-extraction resistance tested by the tester, not asserted by the vendor datasheet), key-migration ceremony (v1 software keys re-wrapped, never silently promoted — a key created Software stays Software-labeled for its lifetime; rotation documented in release notes). Until all four gate, the Settings → Security → Hardware keys row reads "Not available on this device (v1)" with the §27 failure-UX wording discipline (honest grey, not a dead toggle that looks broken).

## 27. Verified-boot failure UX (red/orange screens, exact wording + support flow)

State vocabulary (AVB green flag-2 §2 restated as pixels — `ro.boot.verifiedbootstate` drives all three, About shows the same word the boot screen showed so screenshots and Settings agree): GREEN (locked + verified — normal boot, no warning, About "Verified boot: on"), ORANGE (unlocked bootloader — dev/eng only, persistent warning every boot, About "Unlocked — not for daily use"), RED (verified-boot failure: corruption or rollback-refusal — boot halted, no bypass without data loss, About unreachable so the screen itself carries the support code).

Exact screen copy (committed in `security/vb-screens.md`, translations for top-12, support trained verbatim — wording drift between screen/docs/support is filed as a P1 trust bug):
- ORANGE (5s dwell, power-button skips, never skippable-by-default-flag): title "Unlocked bootloader", body "This device doesn't verify its software before starting. Only use test builds here — banking, work, and personal accounts are at risk.", buttons "[Continue once] [Open guide]" (guide = offline HTML in recovery explaining re-lock + data-loss warning; nightly-expiry ch.09 §12 noted where applicable: "test build expires <date>").
- RED-corruption (`dm-verity` panic §14 boot-critical path): title "Software check failed", body "Your device found damaged or modified system software and stopped to protect your data. Code VB-R1. Your photos/messages are still encrypted.", buttons "[Try again] [Factory reset (erases)] [Support options]" — Try-again re-attempts the same slot once then offers slot-fallback (ch.09 §4 health path) with the count shown ("attempt 2 of 2"); Factory-reset routes to the §21 `halide-wipe --verify` flow with its own confirms (never one-tap from a panic screen — pocket-tap wipe is the nightmare); Support-options shows QR of redacted `vbmeta` digest + rollback-index + slot (no IMEI/IMSI — §7 log rules apply to pixels too) for the support script.
- RED-rollback (old image refused, rollback-index monotonic §2): title "Outdated software blocked", body "This version was blocked by rollback protection (Code VB-R2). Install the newest update instead of this older one.", buttons "[Install latest] [Support options]" (no "boot anyway" — bypassing rollback is the downgrade attack; the absence of the button is the control, stated in the guide).

Support flow (`support/vb-fail.md` playbook, roleplayed per ch.05 §18 launch list): (1) ask for the Code (VB-R1/R2) + QR digest, never ask for PIN/PUK/passwords (stated on the screen footer "Support will never ask for your PIN" — social-engineering inoculation printed where the victim looks); (2) R1 → guide slot-fallback then re-flash canonical from transparency repo (ch.09 §17 verify: hash + avbtool + rollback) then re-bless data per ch.05 §12 tolerance; R2 → update-only path, explain why the old image is refused (one-paragraph rollback rationale, no crypto lecture); (3) unresolved R1 ×2 → RMA-quarantine with the §21 wipe-verify-fail discipline (half-verified device never ships back as "clean"); (4) every case files `security/vb-fail-<date>.md` (code, digest prefix, slot, outcome — trend input to the §24-family review: rising R1 on one SKU = flash-wear/firmware ticket, not user error).

Drills/tests: quarterly sacrificial-unit bit-flip (§14) asserts the RED-corruption screen + code + QR shape; rollback-refusal test (§2 quarterly) asserts RED-rollback copy + no-bypass (attempt bypass via fastboot → refused + logged); orange-dwell timing asserted on eng builds (skip-hold ≤5s, warning unskippable-by-default). Eng `VERITY OFF` watermark (§14) never appears on RED/ORANGE release screens (watermark is eng-only; release failure screens carry codes, not watermarks — confusion between the two fails the test).

## 28. Wipe-verify sampling statistics (proving erase at factory scale, not one phone at a time)

§21 defines the per-device canary+header procedure; this section defines the sampling math that lets a factory line (and enterprise auditors) trust thousands of wipes without hexdumping every byte of every phone. Population model: each wiped unit contributes a PASS/FAIL (§21 step-4 verify) + canary-absent assert + header-rotated assert; failures are `WIPE-VERIFY-FAIL` quarantined per §21 (never reworked silently — rework requires a new canary cycle + new attestation line, linked by `retry-of:` id so pass-after-retry can't hide the first fail).

Acceptance sampling (attribute plan, committed in `factory/wipe-aql.md`): AQL 0.25% critical-defect (a device leaving the line with recoverable pre-wipe plaintext = critical, not major — the bar is set here so QA can't negotiate it later), inspection Level II per lot (lot = one shift-one-station, ≤500 units): sample sizes from the standard table excerpt committed in-tree (e.g., lot 281–500 → sample 50, accept 0 / reject ≥1 for critical) — full table pinned, not "see external standard" hand-waving; rejected lot → 100% re-verify (re-run read-only verify, not re-erase — re-erase without diagnosis destroys evidence) + root-cause (station tool version? `blkdiscard` skipped on wear-level reserve? LUKS header backup left on service USB?) + `security/wipe-lot-<id>.md` filed before the line restarts. Continuous-line alternative (high-volume): rolling 200-unit window, halt on 2 fails in window (tighter than lot-AQL because erase failures cluster by station/tooling, not randomly — the rule encodes that physics).

Verification depth per sampled unit (beyond the §21 three windows): full-`blkdiscard`-trim confirmation (`--verbose` trim-range log archived per lot, 1% of lot), plus quarterly deep-read on 5 sacrificial units per station (chip-off-forbidden — controller-level read via vendor tool only, documented limit: flash over-provisioning regions are attested by `blkdiscard`+crypto-erase composition argument, not bit-proven — the residual is stated in the audit report, matching §23 supply-chain honesty for factory tooling). Canary design hardened for sampling: per-unit random 32-hex (§21) + per-lot secret second canary injected by QA into 1-in-20 units unknown to operators (operator can't pre-pass by caching canary offsets — the blind-canary catch rate is itself dashboarded; 0 blind-canary fails in a quarter with <50% blind coverage triggers coverage-increase, not celebration).

Records & audit: per-unit attestation (§21 line) bulk-uploaded to lot manifest (`factory/wipe-lot-<id>.csv`: serial-hash (salted, no raw serial in git — privacy rule), sku, timestamp, verify PASS/FAIL, header-sha-new prefix, operator-confirm-id, tool-version); lot manifest signed by station key + countersigned weekly by QA (dual-control mirrors §8 ceremony discipline at factory scale); enterprise P3 fleets receive per-device attestation receipts (MDM upload §21) plus quarterly lot-summary (accept-rate, blind-canary rate, tool versions — the evidence an auditor asks for, pre-assembled). Test/CI: `tests/wipe-stats.py` validates any lot CSV (sample-size vs table, accept/reject arithmetic, blind coverage) — a lot manifest that fails arithmetic can't be signed (math errors in erase evidence are audit findings, so the math is gated).

## 29. Vulnerability-reward credit wall ops (no cash bounty v1 per §18 — credit done right)

§18 sets the policy (no cash, credit wall + fast SLA + research builds instead); this section runs the wall as an operation so "credit" isn't a vague promise researchers don't trust. Wall location & form: `security/CREDITS.md` in-repo (versioned — credit survives reverts because it's history) + website mirror (same content, generated from the file, never hand-edited separately — two-source credit walls diverge and insult someone). Entry schema (one row per finding, fixed columns): `date-fixed | handle-or-name (reporter-chosen,PGP-fingerprint-suffixed) | severity-at-triage (§15 bin) | area (boot/lockscreen/bridge/modem-data/OTA/container) | advisory-link | notes (research-build-used Y/N §22)`. Ordering chronological (never severity-ranked — ranking reporters by "importance" breeds gaming; triage bins already record severity where it belongs). Opt-out and anonymity first-class: `anonymous` and `handle-only-no-link` honored without question (credit pressure that forces doxxing chills reporting — the intake form asks preference before fix, default `handle-only`); embargo-period credit withheld until disclosure day (§13 — the wall updates atomically with the advisory, never leaks via early commit; wall-update MR rides the embargo branch, not main).

SLA composition with §15/§18: triage-48h clock includes credit-preference capture (no second round-trip asking "how should we credit you" after the fix — asked once at intake); fix-verification build offered pre-release (§18) ships with the wall-preview line ("you'll appear as … on <date>") so the reporter sees the promise concretely; missed-triage-SLA auto-adds `SLA-MISSED-apology` note on the entry (public accountability for our latency, not buried in a retrospective). Disputes (severity disagreement, credit wording, anonymous-vs-handle change): Security owner decides within 5 business days with written rationale linked from the entry's notes field (disagree-and-commit recorded — researchers who feel heard report again; the dispute log is a metric in the §24-family review: repeat-reporter rate).

Abuse & hygiene: duplicate-report rule (first-substantive-report credited, later duplicates thanked-by-handle in the notes — exact timestamps from intake, no ties broken by reputation); invalid/out-of-scope (§1 scope + §25 pentest-out list) gets a kind decline + scope pointer (declines answered within the 48h triage SLA too — silence is what kills programs, not "no"); annual wall audit (with the §24-family review week: every entry has advisory-link live + handle spelling confirmed + embargo-timing checked — link-rot on a credit wall reads as ingratitude; the audit fixes it). Metrics (§24-family inputs): reports/quarter, valid-rate, MTTR by bin, repeat-reporter %, research-build-attributed % (§22 effectiveness), SLA-miss count with apology notes — published as the annual "how our disclosure program did" paragraph (numbers, not adjectives — same honesty rule as modem perf §11 ch.07).

## 30. Annual control-effectiveness review evidence-sampling SOP (how §24 verdicts get proven, not asserted)

§24 defines the review week, families, and KEEP/TUNE/RETIRE verdicts; this section is the sampling procedure each family owner runs beforehand so review week consumes evidence, never hunts for it. Sampling frame per family (population → sample → artifact, all_RS committed in `security/review-evidence/<year>/` before review week or the family is marked `EVIDENCE-LATE` and reviewed first — lateness is visible, not absorbed):

1. Verified-boot (§2) + dm-verity (§14): population = release builds; sample = 100% of release `vbmeta` (flag-2 + key + monotonic assert via script — cheap, so census not sample) + 1 sacrificial bit-flip log + 1 rollback-refusal log per quarter (4+4/ASK year minimum); artifact: `vb-evid.csv` (build, flag, key-fpr, rollback-index, test-log links).
2. LUKS ops (§9) + wipe-verify (§§21/28): population = lot manifests; sample = all `WIPE-VERIFY-FAIL` + random 30 PASS attestations re-verified (header-SHA rotation recomputed from station logs) + quarterly deep-read reports; artifact: `wipe-evid.md` (accept-rate, blind-canary rate, fail narratives).
3. AppArmor/seccomp/nft (§10): population = `audit.log` + fuzz runs; sample = 200-denial stratified draw (per-bridge) classified true-positive/false-positive with disposition + full nightly-fuzz crash list (crashes are census — every crash has a seed + bin per §15); artifact: `mac-evid.md` + `fuzz-coverage-trend.png`.
4. Patch SLA (§11) + CVE triage (§15): census of bins (every CVE record has disposition + clock math); sample = 10 `NOT-AFFECTED` re-audited by a second reviewer (wrong-not-affected is the dangerous bin — it gets the extra eyes); artifact: `patch-lag-histogram.png` + `cve-bins.csv`.
5. Kernel hardening (§16): census of `.config` asserts per release + 1 mitigation-cost re-measurement per SKU (perf waivers re-proven or expired per the four-part rule); artifact: `hardening-evid.csv`.
6. Lockscreen (§20): population = `tests/lockscreen-5.sh` runs + dogfood wrong-PIN telemetry counters (opt-in §17 ch.05 only); sample = full 30-attempt sacrificial log annually + quarterly 12-wrong runs; artifact: `lockscreen-evid.md`.
7. Researcher builds (§22) + credit wall (§29): census of researcher list + wall entries (link-liveness checked); artifact: researcher-stats + wall-audit note.
8. Supply-chain (§23): per-class review-trigger log (did each trigger fire when its condition occurred? modem-fw advisories, endpoint cert changes, APN-fallback rates, meter calibrations — unfired triggers are findings); artifact: `supply-evid.md`.

Verdict thresholds (so KEEP/TUNE/RETIRE isn't vibes): KEEP requires evidence-complete + ≥1 caught-anything event or a red-team proof the control would catch (a control that never fires and was never tested is `UNPROVEN`, not KEEP — it gets a live-fire task or TUNE); TUNE requires named change + owner + quarter (carried to OKRs per §24, max 3 per family); RETIRE-with-replacement requires the dual-sign + ADR (§24) plus a migration window where both controls run (no flag-day retirements on security controls). Sampling randomness: `tests/review-sample.py` (seeded `--seed <year>`, committed seed — anyone can reproduce the draw; hand-picked "representative" samples rejected by the tool). Output wiring: `security/control-review-<year>.md` per-family verdict cites artifact hashes (evidence pinned, not "see dashboard"), risk-register delta proposed to Program (ch.11) with the sampled counts attached — the register learns from measurement, per §24's closing rule.

## 31. SELinux neverallow audit expansion (per-domain allowlist, audit2allow ban procedure, CI grep)

Parent: §4 MAC coexistence + §10 AppArmor/seccomp/nft + §11 per-MR `sepolicy-neverallow` job (ch.09 §11). The per-MR neverallow job proves the build contains no globally-forbidden allow rules; this section proves the remaining allowed rules are each owned, minimal, and reviewed — closing the gap between "no neverallow violation" (necessary) and "least privilege actually holds" (sufficient). Scope covers Android SELinux domains in `device/halide/sepolicy/` + host-adjacent `container` domain (`u:r:container:s0` §4) where SELinux applies on the host side; AppArmor/seccomp deltas live in §10 and are cross-referenced, never duplicated here. Policy sources pinned per release (AOSP tag + device fragment SHAs recorded in `security/selinux-pins.md` — an unpinned policy input fails `halide-manifest verify`-adjacent `sepolicy-pin-check.sh` the same way an unpinned builder input fails ch.09 §13).

Per-domain allowlist (normative excerpt; full file `security/selinux-allowlist.csv` governs with columns `domain,typeclass,perm_set,target,justification_bug,owner,expiry,last_audit`): every allow rule committed must resolve to exactly one row below (or a CSV row with the same shape for sub-domains); an allow rule without a row is a release-blocker even when neverallow is green.

| Domain | Allowed (bounded) | Neverallow guard (binding examples, non-exhaustive — full list in `sepolicy/neverallow.te`) | Baseline denial budget (quarterly `avc: denied` diff §4) | Owner + re-audit |
|---|---|---|---|---|
| `u:r:container:s0` (LXC boundary §4) | binderfs/dri/snd binds, bridge-socket `connectto` only for SOCKETS.md paths, `read` on `halide-release` + vbmeta-digest node | `neverallow container self:capability sys_admin; neverallow container persist_block:blk_file write; neverallow container self:process ptrace; neverallow container kernel:system module_request` | 0 new denials vs baseline without bug ID; any `ptrace`/`sys_admin` attempt = P0 + §12 live-fire input | Security + Platform, quarterly |
| `halide-bridges` (per-bridge sub-domains `halide-bridge-<name>`) | per-bridge socket `bind/create` for its own path only, binder-ioctl to container bridge only, no `execve` (mirrors §10 seccomp `execve`-deny — both layers assert, either layer may catch) | `neverallow halide-bridge-* self:process execmem execmod; neverallow halide-bridge-* self:process execve; neverallow halide-bridge-*:socket * relabelto; neverallow halide-bridge-a halide-bridge-b:socket connectto` (cross-bridge connection banned — bridges talk via the broker, never peer-to-peer) | per-bridge denial budget in CSV (default 0; parsers that legitimately probe fallbacks get a numbered budget with expiry, never a blanket) | Bridge owner + Security, per-MR + quarterly |
| `halide-composer` | dri + wayland-socket + input-socket only (§10 profile restated as SELinux where applicable); `read` on display-calibration blob | `neverallow halide-composer self:capability net_admin net_raw; neverallow halide-composer persist_block:blk_file write` | 0 network-denial suppressions (any `net_raw` ask files a STRIDE row §23, not a policy line) | Graphics + Security, quarterly |
| `halide-radio-helper` (ch.07 QRTR/QMI path) | `qmi_wwan`-node `read/write/ioctl` on the labeled modem node only, AT-port `read/write` on the single claimed port, `nlmsg` to MM-helper only | `neverallow halide-radio-helper modemst_block:blk_file write; neverallow halide-radio-helper self:capability sys_rawio; neverallow halide-radio-helper efs_block:blk_file *` (modemst/efs writes go through the §16 factory backup tool, never the runtime helper) | QRTR-audit denials reviewed with ch.07 §15 stall ladder (denial storm + stall correlation = P0) | Telephony + Security, quarterly |
| `halide-ota` (update_engine sidecar) | inactive-slot `blk_file write` on slot-suffixed nodes only, `read` on payload staging dir, `setactive` via bootctl-helper transition only | `neverallow halide-ota active_slot_block:blk_file write; neverallow halide-ota self:process execve; neverallow halide-ota keys_file:file read` (OTA verifies with pubs via the verified path — it never reads private-key material by construction) | any active-slot write attempt = P0 + rollout freeze (ch.09 §20 halt input) | Release + Security, per-release + quarterly |
| `recovery` | `blk_file write` on userdata only via `halide-wipe --verify` transition (§21 single-implementation rule restated as domain transition — no other recovery domain may write userdata), redacted-log `append` only | `neverallow recovery userdata:file read` (recovery never mounts userdata decrypted without auth §3 ch.09 §5 — the neverallow line makes the "never" mechanical); `neverallow recovery self:capability dac_override` | 0 userdata-read denials suppressed (each is a bypass attempt until proven otherwise) | Security + Release, quarterly |
| `halide-debug` (userdebug/eng only, never `user`) | `adb`-gated `ptrace` on own-UlD processes, `read` on tombstones/ramoops for `halide-log-collect` | `neverallow user halide-debug:process *` (the domain must not exist on `user` builds — CI asserts absence via `sesearch --allow | grep halide-debug` empty on `user`; presence on `user` = wrong-variant P0 per ch.09 §18 `testkey` row) | eng-only denials never promoted to allow rules on `user` (promotion requires Arch + Security dual sign + §16-style waiver with expiry) | Security, per-build-variant gate |

`audit2allow` ban procedure (binding — every `audit2allow`-shaped change follows this ladder, no direct allow-commit from tool output):

1. Denial capture: failing run must attach the raw `audit.log` slice + `audit2why` output + reproducing command (`tests/<area>-*.sh` line or fuzz seed id) — a policy change without a reproducer is rejected in review (same doctrine as ch.10 §11 fix + 50-green streak: no proof, no merge).
2. `audit2allow` output quarantined: tool output lands in the MR description as `SUGGESTED-BY-TOOL` (never committed as `.te` directly — the header `audit2allow-generated` in a committed file fails CI with the file named, see grep gates below).
3. Human minimization: author rewrites the suggestion as the narrowest rule that fixes the reproducer (single domain, single class, minimal perm set, labeled target — `allow halide-bridge-x self:capability *` is rejected on sight; `allow halide-bridge-sms cnode:sock_file { write }` with the SOCKETS.md path cited is the shape of an acceptable rule).
4. Justification block (mandatory comment above every new allow, lint-checked): `bug-ID + SOCKETS.md/bridge-spec ref + expiry (≤90 days for workarounds, `permanent-with-annual-review` only with Security sign) + test-ID that fails without the rule and passes with it` (mirrors §4 exception-comment rule extended with the failing-test proof — a rule without a test is a rumor).
5. Second-reviewer rule: Security owner + domain owner both approve (same dual-sign as ch.08 §16 perf waivers — schedule pressure cannot waive least-privilege); cross-bridge or container-boundary rules additionally need Arch sign (boundary crossings are architecture, not trivia).
6. Expiry enforcement: `sepolicy-expiry-bot` files `EXPIRED-POLICY` issues 14 days before each expiry (bot nags, humans dispose per ch.09 §25 gardening doctrine); expired rules fail the build (fail-closed — an expired workaround that still builds is a permanent hole with paperwork, banned here as in §16).

CI grep gates (per-MR `sepolicy-neverallow` job extended, ch.09 §11 pipeline — all three must be green, any red blocks merge with the file + line named):

```bash
# 1. neverallow compile gate (existing, restated as gate text so waivers need an ADR, not a shrug)
m neverallow_check device/halide/sepolicy/ || fail "neverallow violated — fix policy, never blanket-allow"
# 2. audit2allow-ban grep (new): committed tool output + wildcard allows rejected
! grep -rn "audit2allow-generated\|allow .* self:capability \*\|allow .* \*:.* \*" device/halide/sepolicy/ \
  || fail "tool-paste or wildcard allow at $(grep -rn ... | head -1) — follow §31 minimization ladder"
# 3. justification-block lint (new): every ^allow line must have bug+expiry+test comment in the 5 lines above
scripts/sepolicy-comment-lint.sh --require-bug --require-expiry --require-test \
  || fail "allow without bug/expiry/test block — see §31 step 4"
# 4. user-variant absence gate (new): debug domain + permissive must not exist on user
[ "$VARIANT" = user ] && sesearch --allow -s halide-debug | grep -q . \
  && fail "halide-debug on user build — wrong variant (ch.09 §18 row)"
[ "$VARIANT" = user ] && getenforce_variant_check enforcing \
  || fail "user build not enforcing"
```

Quarterly neverallow audit (the §4 `avc: denied` diff made executable): QA pulls 90 days of `audit.log` from dogfood-opt-in (§17 ch.05 consent only — no silent log harvesting) + nightly fuzz runs + soak units (ch.10 §15); `scripts/avc-diff.sh <baseline> <current>` emits per-domain new-denial counts vs the CSV budgets; every new denial gets one of three dispositions within the §15 clocks (`ALLOW-WITH-RULE` via the 6-step ladder, `MITIGATED-BY-CONFIG` with the blocking AppArmor/seccomp/nft rule named + demonstrating test per §15 MITIGATED proof rule, `PRODUCT-BUG` filed against the area with the denial as the reproducer). Audit artifact `security/avc-audit-<quarter>.md` (counts, dispositions, expired-rule renewals-or-removals, coverage-trend link from §17 fuzz dashboard) is an input to the §24-family review week (no audit file = family marked `EVIDENCE-LATE` per §30 sampling SOP).

Expected outputs: `security/selinux-allowlist.csv` (per-domain rows + budgets + owners + expiries); `security/selinux-pins.md` (AOSP tag + fragment SHAs per release); `scripts/sepolicy-comment-lint.sh` + `scripts/avc-diff.sh` (gates green on every MR/nightly); `security/avc-audit-<quarter>.md` (denial counts + dispositions + expiry actions); §24-family review input (audit file linked with artifact hashes per §30).

- [ ] Every committed allow resolves to an allowlist CSV row (bug + owner + expiry + test); tool-paste/wildcard grep green.
- [ ] Six-step audit2allow ladder followed with dual sign (triple for boundary crossings); expired rules fail the build.
- [ ] `user` builds carry no `halide-debug` domain and boot enforcing (variant gate green + `getenforce` evidence attached).
- [ ] Quarterly `avc: denied` diff filed with dispositions inside §15 clocks; fed to the §24-family review (no `EVIDENCE-LATE`).

## 32. FDE/FBE key-derivation parameter registry (Argon2id m/t/p, AES-XTS key sizes, rotation ceremony deltas)

Parent: §3 encryption-at-rest + §9 LUKS2 operations + §8 key hierarchy/ceremony + §21 wipe-verify. Parameters that live in engineers' heads ("we use Argon2id, it's fine") drift across SKUs and releases until unlock latency triples on the slow cores or a SKU ships a weaker KDF nobody chose. This section is the registry where every KDF/cipher number is written down, bounded, and gated — the same pinning discipline ch.09 §13 applies to builder inputs, applied to crypto parameters. `security/kdf-registry.json` is normative (CI-validated schema, per-SKU entries, rotation due dates); prose here explains, the JSON governs.

Registry (`security/kdf-registry.json`, one entry per SKU + `default` fallback that new SKUs inherit until measured — inheritance is explicit in the file, never assumed):

| SKU / scope | LUKS2 cipher + key size | Argon2id m (memory) / t (iterations) / p (lanes) | Unlock-latency SLO (measured §9) | FBE policy (inside LUKS volume §9 single-prompt rule) | Rotation due + custodian ref |
|---|---|---|---|---|---|
| `default` (new-SKU inherit) | `aes-xts-plain64`, 512-bit (256-bit data + 256-bit tweak — XTS key-size wording fixed here so release notes never write "256-bit XTS" ambiguously) | m=1GB cap / t=4 / p=2 (mobile-SoC cap per §9 — memory over 1GB OOMs the slow cores during early-boot derive; lanes=2 matches little-core topology, measured not copied) | p50 ≤2.0s, p95 ≤3.0s on REF-A slow cores (screen-on to keyring-available) | AOSP FBE per-app keys wrapped by LUKS-unlocked keyring (`security/key-flow.dot` path PIN → KDF → LUKS → volume key → FBE master → per-app); no double-passphrase prompt (two prompts = UX fail §9) | rotation review annual with ceremony log (ch.08 §8 cadence); custodian roster `keys/custodians.md` |
| REF-A (SDM845, 6–8GB RAM class) | `aes-xts-plain64` 512-bit, sector 4096, `pbkdf argon2id` | m=1024MB / t=4 / p=2; `cryptsetup luksDump` archived per release (keyslot 1 + escrow-only-where-enterprise-demands §9) | p50 1.4s / p95 2.6s (recorded `power/<sku>`-adjacent `security/unlock-<sku>.md` with unit label + firmware + ambient per ch.10 §12 footnote discipline) | FBE `AES-256-GCM` file keys (AOSP default where available), master wrapped at LUKS-unlock; suspend keeps keys in memory (stated posture §9, not hidden) | LUKS re-encrypt review per major release; escrow-slot audit quarterly (universal-backdoor slot = P0 compromise drill §8) |
| REF-B (newer SoC class, ≥8GB) | `aes-xts-plain64` 512-bit, sector 4096 | m=1536MB / t=4 / p=4 (bigger-memory SKU earns stronger m only after unlock SLO still met — m raised from 1024 only with p50/p95 evidence in the MR, never by optimism) | p50 ≤1.6s, p95 ≤2.5s (faster SoC must beat REF-A, not merely match — regression vs REF-A filed as P1 perf bug) | same FBE wrap as REF-A; `hb_strongbox_`-prefixed aliases refused `ATTESTATION_IMPOSSIBLE_V1` (§26 — software keys never mislabeled) | same annual cadence; any m/t/p change is a rotation-ceremony delta below (never a silent config edit) |
| Recovery / `halide-wipe` path (§21) | same cipher as host userdata (wipe operates the same slots it erases — mismatched-cipher wipe tooling refused by `halide-wipe --verify` preflight) | KDF verify-only (no derive tuning in recovery; recovery authenticates via the host daemon verdict — container keyguard slaved to host §20 single-lock authority) | n/a (wipe path has no unlock SLO; it has the §21 verify SLO: canary-absent + header-rotated + attestation) | n/a (FBE masters destroyed with the LUKS data keyslot — crypto-erase composition argument §28 sampling section cites) | wipe-tool version pinned with the registry (tool bump without registry bump fails `kdf-registry-check.sh`) |
| Research builds (§22) | same as host SKU under test (research measures the real KDF, never a weakened lab KDF — weakened-KDF research builds would launder perf numbers) | same m/t/p as the SKU (stated in `security/researchers.md` scope note so hunters test the shipped cost) | report-only (no SLO enforcement on research — KASAN + symbols skew timing; numbers tagged `RESEARCH-UNCALIBRATED`) | same FBE wrap; research key separation (§22) covers signing, never KDF weakening | research KDF deltas banned (any research image with non-registry m/t/p fails the build — the ban is mechanical, not cultural) |

Rotation ceremony deltas (changing m/t/p, cipher, or sector size is a ceremony, not a config edit — quorum discipline §8/§19 applies at crypto scale): proposal MR carries (a) measured unlock deltas on both REFs (p50/p95 before/after, 20-run median, footnote set ch.10 §12), (b) `cryptsetup benchmark` + `lmbench` rows for the mitigation-cost sheet (§16 `security/mitigation-cost.md` — KDF cost reviewed beside kernel-mitigation cost so total boot tax is visible), (c) migration path (existing-userdata re-encrypt via `cryptsetup reencrypt` in recovery with battery ≥50% + charger + backup-first per ch.09 §10 GPT-backup doctrine extended to LUKS headers; header backup SHA logged pre/post; failed re-encrypt rolls back to the old header, never strands), (d) dual-sign transition note where the change alters the unlock flow (release N accepts old+new derived wrappings, N+1 new-only, N+2 drops old — same N/N+1/N+2 rhythm as §8 key rotation so support explains one pattern once). Ceremony execution mirrors §8 (two custodians, offline attestation of the new `kdf-registry.json` SHA read aloud, transparency entry in `halide-transparency` adjacent to `signatures.json`, `anomalies-or-none` line required). Emergency KDF change (weakness found: e.g., Argon2id parameter later judged insufficient) rides the ch.09 §21 hotfix lane as a security `PATCH-NOW` (T+0 decision → T+24h go/no-go) with the re-encrypt path validated on sacrificial units before 1% (bricking 1% of user data to fix a theoretical KDF weakness is the cure worse than the disease — validated first, stated here so the clock can't skip it).

Gates + drills (mechanical, not aspirational): `scripts/kdf-registry-check.sh` runs per-MR + per-release (schema-valid JSON, every SKU resolves with no silent fallback past first boot, `cryptsetup luksDump` slot count + cipher + KDF match the registry row for the built SKU, unlock-latency file present and within SLO on `user` builds, no research-image KDF delta, no `PRIVATE KEY`/escrow anomaly). Lockscreen-5 harness (`tests/lockscreen-5.sh` §20) doubles as the KDF rate-limit proof (10-wrong → 30s doubling ladder asserts the KDF isn't bypassable via counter reset — reboot-persistence + fsync-per-attempt rules §20 cited as KDF-adjacent controls). Annual rotation drill (with the §19 Shamir stand-in drill, same calendar week): re-split + re-derive on a sacrificial unit end-to-end (old header → re-encrypt → new header SHA differs + old wrapped key fails + canary-equivalent unlock probes pass), timed and filed as `security/kdf-drill-<date>.md` (unlock p50/p95 + re-encrypt duration + rollback-path demo). Failed drill or SLO miss = P0 (erase/unlock is the last promise per §21 — it doesn't get "known issue" status; KDF SLO misses ride the same severity).

Expected outputs: `security/kdf-registry.json` (normative per-SKU m/t/p + cipher + SLO + rotation due); `security/unlock-<sku>.md` (20-run latency tables with footnotes); per-release `cryptsetup luksDump` archive + `kdf-registry-check.sh` PASS; rotation-ceremony log (`keys/ceremonies/kdf-<date>.md` with dual-sign + transparency id + header SHAs before/after); annual `security/kdf-drill-<date>.md` (re-encrypt + rollback demo + timings).

- [ ] Registry JSON schema-valid with every shipping SKU resolved (no silent default past first boot); CI `kdf-registry-check.sh` green.
- [ ] LUKS cipher 512-bit XTS + Argon2id m/t/p match the built SKU row (`luksDump` archived, slot count = 1 + escrow-only-where-demanded).
- [ ] Unlock p50/p95 within SLO on REF slow cores (20-run median, footnotes); research images carry identical m/t/p (no weakened lab KDF).
- [ ] KDF/cipher changes ride rotation ceremony with dual sign + transparency entry + re-encrypt + rollback demo (never silent edits).
- [ ] Annual KDF drill filed (re-encrypt duration + header rotation + old-key-fails proof); SLO miss or drill fail = P0.

## 7. Hardening checklist (release gate)

- [ ] `getenforce` → Enforcing (host SELinux where applicable + container), `aa-status` → profiles loaded+enforcing.
- [ ] `avbtool info_image` → flag 2, correct key, rollback monotonic.
- [ ] `cryptsetup luksDump` → Argon2id, no weak slots; brute-rate-limit tested (wrong PIN ×10 → delay).
- [ ] Seccomp filters on bridges; fuzz smoke green; `nft list ruleset` matches committed baseline.
- [ ] Patch level ≤60 days; kernel CVE scan (`cvecheck`-equivalent) attached to release notes.
- [ ] Signing ceremony log + transparency entry published; no `PRIVATE KEY` material in git (scanner green).
- [ ] Crypto-erase canary test passes on sacrificial unit; USB defaults to charge-only; `ro.adb.secure` enforced.
- [ ] Lockscreen 12-wrong-PIN script passes (delays + reboot persistence + emergency reachable).
- [ ] Wipe-verify drill passes (canary absent + header rotated + attestation logged).
- [ ] Research builds use research key + watermark + expiry (no release-key overlap).
- [ ] Supply-chain review dates current; annual control-effectiveness review filed.
- [ ] Keystore level asserts `software`/`tee` truthfully (never `strongbox` on v1); `hb_strongbox_` prefix refused with docs link.
- [ ] VB failure screens show exact copy + codes (VB-R1/R2); QR carries digest/rollback/slot only (no IMEI/IMSI); support playbook roleplayed.
- [ ] Wipe lot manifest passes `wipe-stats.py` (sample-size math, blind-canary coverage, dual signatures present).
- [ ] Credit wall updated atomically with advisories (links live, preferences honored, SLA-miss apologies where due).
- [ ] Control-review evidence packs complete per family (seeded samples reproducible, verdicts cite artifact hashes).
- [ ] `avbtool info_image` → flag 2, correct key, rollback monotonic.
- [ ] `cryptsetup luksDump` → Argon2id, no weak slots; brute-rate-limit tested (wrong PIN ×10 → delay).
- [ ] Seccomp filters on bridges; fuzz smoke green; `nft list ruleset` matches committed baseline.
- [ ] Patch level ≤60 days; kernel CVE scan (`cvecheck`-equivalent) attached to release notes.
- [ ] Signing ceremony log + transparency entry published; no `PRIVATE KEY` material in git (scanner green).
- [ ] Crypto-erase canary test passes on sacrificial unit; USB defaults to charge-only; `ro.adb.secure` enforced.
- [ ] Lockscreen 12-wrong-PIN script passes (delays + reboot persistence + emergency reachable).
- [ ] Wipe-verify drill passes (canary absent + header rotated + attestation logged).
- [ ] Research builds use research key + watermark + expiry (no release-key overlap).
- [ ] Supply-chain review dates current; annual control-effectiveness review filed.

Next: `09-build-ota-factory-ci.md`.
