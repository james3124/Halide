# Rollout HALT template (ch.11 S27 bake rules: halt procedure is binding).
# Copy to program/rollout/<ver>-HALT.md on any halt trigger. Status page banner
# <=4h; fleet notified <=24h; postmortem within 14 days (blameless, linked from
# advisory). Resume requires a NEW version restarting at stage 1 (no
# resume-in-place after P0/trust halt; P1-only halts may resume at stage 2 with
# QA+Release co-sign + ADR).

Version: TODO (halide-<YYYYMMDD>-<sha12>)
Reason: TODO
Affected-stages: TODO (1 lab soak / 2 dogfood / 3 staged 1/10/50/100 / 4 stamp)
Build-IDs: TODO
Workaround-or-hold for fleet: TODO
Crash-free-rate: TODO (halt if <99.0%; promote if >=99.5%)
Status-page-banner-UTC: TODO (<=4h SLA)
Fleet-notified-UTC: TODO (<=24h SLA)
Postmortem-link: TODO (<=14 days)
Resume-plan: TODO (new version at stage 1, or stage-2 resume with co-signs + ADR)
