# War-room template (field-issue-escalation S3: fleet-incident protocol).
# Trigger: S0, or >=3 S1 same fingerprint within 72h, or staged-rollout
# auto-halt. Copy to fleet/WAR-<id>.md (fleet dir owned by Release lane;
# template lives here so Support can open one without new permissions).
# Commander: Release (button) + QA (repro) + Security if P0.

Start-UTC: TODO
Fingerprint-range: TODO
MANIFEST-range: TODO
Halt-status: TODO (freeze beyond current stage 1%/10%/50% - no one-more-stage)
Commander: TODO (Release) / Repro: TODO (QA) / Comms: TODO / Data: TODO
Paged: TODO (S0 within 1h / S1-cluster within 4h)
Updates: TODO (30-min S0 / 4h S1-cluster; each: new data / decision / owner+time)
Contain (ranked): halt rollout -> per-serial hold (halide-fleet-check --war <id>)
  -> feature safe-mode (halide-<x>-bridge --safe-mode) -> hotfix
Close: root cause + MANIFEST delta blamed + regression test merged + retro <=7d.

## User comms (templates verbatim, honesty + no fake claims)
S0: status page + P3 fleet + forum pin, <=24h from open, daily until mitigation.
S1: forum + release notes + fleet digest, <=72h, per train. S2: release notes.
Fleet P3 channel gets T-24h pre-notice on S0 with per-serial affected check.
