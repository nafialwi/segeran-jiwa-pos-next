# PROJECT STATE - FIN-P2A LOCKED_REMOTE

## Canonical identity

- Workspace: Segeran Jiwa Next Vol. 1
- Product: Segeran Jiwa POS Next
- Blueprint: v1.0 FINAL LOCK
- Current milestone: FIN-P2A - Shift Funding Bridge - LOCKED_REMOTE
- Current branch: work/cs06743-patch3-hardening
- Technical source: 97fb82afa34f09936955df2bf65a3c91d9b2be62
- Managed hosted migration: fin_p2a_shift_funding_bridge
- Release guard: PROCESS-GUARD
- Production automatic deployment: DISABLED

## Progress

- Blueprint / Design: 100%
- CS-01: 100%
- CS-02: 100%
- CS-03: 100%
- CS-04: 100%
- CS-05: 100%
- CS-06: 100%
- Finance milestone: IN PROGRESS; FIN-P1 and FIN-P2A locked
- Whole-project weighted progress: 78.0%

The finance roadmap bucket remains unearned until the complete finance milestone acceptance gate is locked.

## Current verified state

- FIN-P1 finance foundation is locked.
- KAS_SHIFT exists as a canonical finance account.
- Business-wide finance reads are Owner-only.
- Owner transfer/capital/personal-withdrawal commands are hosted and verified.
- FIN-P2A now prevents positive shift opening cash from appearing without source.
- Positive opening from Kas Utama creates one canonical Kas Utama -> Kas Shift transfer.
- Funded opening is idempotent and records immutable source provenance on the shift.
- Legacy positive opening fails closed; legacy zero opening remains supported.
- Hosted FIN-P2A behavior regression passed and rolled back.
- Final canonical verify after hosted FIN-P2A apply: PASS.
- Production automatic deployment remains disabled.

## Historical provenance note

The hosted Supabase migration-history table does not list every historical CS-04 through CS-06 source migration although their hosted objects are present. Current finance migrations are recorded normally in managed migration history.

The original Blueprint v1.0 FINAL LOCK path referenced by older state files is not present in the current working tree. Finance implementation has been reconciled against the authoritative one-file handoff snapshot; no Blueprint rule was silently invented.

## Source of truth order

1. Blueprint v1.0 FINAL LOCK / authoritative handoff snapshot
2. Decision / Change Control records
3. docs/checkpoints/PROJECT_STATE.md
4. docs/checkpoints/ROADMAP_PROGRESS.md
5. docs/checkpoints/FIN-P2A_CHECKPOINT_REPORT.md
6. docs/checkpoints/FIN-P1_CHECKPOINT_REPORT.md
7. docs/superpowers/specs/2026-09-20-fin-p2a-shift-funding-bridge-design.md
8. docs/checkpoints/RELEASE_MANIFEST.json

## NEXT ACTION

FIN-P2B  Shift Expense Fact.

Do not implement unresolved Kasbon repayment/deduction semantics or month-close/reopen rules until their authority is explicitly locked.
