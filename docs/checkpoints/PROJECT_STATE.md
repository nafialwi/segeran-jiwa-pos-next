# PROJECT STATE - FIN-P2B LOCKED_REMOTE

## Canonical identity

- Workspace: Segeran Jiwa Next Vol. 1
- Product: Segeran Jiwa POS Next
- Blueprint: v1.0 FINAL LOCK
- Current milestone: FIN-P2B - Shift Expense Fact - LOCKED_REMOTE
- Current branch: work/cs06743-patch3-hardening
- FIN-P2B technical source: 21d9ef36cc3e03e52ef71dbbed95138fab988a29
- FIN-P2B index hardening: 5a4ab5a5a7379cdd392075849b5ab0ca0291e18f
- Managed hosted migrations: fin_p2b_shift_expense; fin_p2b1_expense_index_hardening
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
- Finance milestone: IN PROGRESS; FIN-P1, FIN-P2A, and FIN-P2B locked
- Whole-project weighted progress: 78.0%

The finance roadmap bucket remains unearned until the complete finance milestone acceptance gate is locked.

## Current verified state

- FIN-P1 finance foundation is locked.
- KAS_SHIFT exists as a canonical finance account.
- Business-wide finance reads are Owner-only.
- Owner transfer/capital/personal-withdrawal commands are hosted and verified.
- FIN-P2A shift funding bridge is locked and positive shift opening cannot appear without an explicit source.
- FIN-P2B Shift Expense is now a typed immutable business fact linked to one canonical EXPENSE movement and one actual-shift CASH_OUT.
- CASH sale finance posting is aligned to KAS_SHIFT.
- Generic untyped cash mutation fails closed.
- Kasir expense visibility is own-shift scoped; Owner receives consolidated visibility.
- Hosted FIN-P2B behavior regression passed and rolled back.
- FIN-P2B1 covering-index hardening cleared the two new unindexed-FK advisor findings.
- Final canonical verify before checkpoint: PASS (73 JS / 123 Python).
- Production automatic deployment remains disabled.

## Historical provenance note

The hosted Supabase migration-history table does not list every historical CS-04 through CS-06 source migration although their hosted objects are present. Current finance migrations are recorded normally in managed migration history.

The original Blueprint v1.0 FINAL LOCK path referenced by older state files is not present in the current working tree. Finance implementation has been reconciled against the authoritative one-file handoff snapshot; no Blueprint rule was silently invented.

## Source of truth order

1. Blueprint v1.0 FINAL LOCK / authoritative handoff snapshot
2. Decision / Change Control records
3. docs/checkpoints/PROJECT_STATE.md
4. docs/checkpoints/ROADMAP_PROGRESS.md
5. docs/checkpoints/FIN-P2B_CHECKPOINT_REPORT.md
6. docs/checkpoints/FIN-P2A_CHECKPOINT_REPORT.md
7. docs/checkpoints/FIN-P1_CHECKPOINT_REPORT.md
8. docs/superpowers/specs/2026-09-20-fin-p2b-shift-expense-design.md
9. docs/checkpoints/RELEASE_MANIFEST.json

## NEXT ACTION

FIN-P3 - Customer Debt Foundation.

Do not implement unresolved employee Kasbon repayment/deduction semantics or month-close/reopen rules until their authority is explicitly locked.
