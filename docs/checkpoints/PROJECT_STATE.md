# PROJECT STATE - FIN-P6 LOCKED_REMOTE

## Canonical identity

- Workspace: Segeran Jiwa Next Vol. 1
- Product: Segeran Jiwa POS Next
- Blueprint: v1.0 FINAL LOCK
- Current milestone: FIN-P6 - Expense Approval - LOCKED_REMOTE
- Current branch: work/cs06743-patch3-hardening
- FIN-P6 planning source: 3e27f4cf7fa5db347a958922376c69945f88878f
- FIN-P6 technical source: e8195d0f1cde2c47295a35a22fbe5abb5aff54e8
- Managed hosted migration: fin_p6_expense_approval
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
- Finance milestone: IN PROGRESS; FIN-P1 through FIN-P6 locked
- Whole-project weighted progress: 78.0%

The Finance roadmap bucket remains unearned until its complete acceptance gate is locked.

## Current verified state

- FIN-P1 Finance Foundation: LOCKED_REMOTE
- FIN-P2A Shift Funding Bridge: LOCKED_REMOTE
- FIN-P2B Shift Expense Fact: LOCKED_REMOTE
- FIN-P3 Customer Debt Foundation: LOCKED_REMOTE
- FIN-P4 QRIS Settlement & Daily Finance Reconciliation: LOCKED_REMOTE
- FIN-P5 Supplier Payable Foundation: LOCKED_REMOTE
- FIN-P6 Expense Approval: LOCKED_REMOTE
- Owner can configure expense approval by category/amount threshold.
- Matching expense requests remain financially inert until Owner approval.
- Approved expenses post through canonical Shift cash and money ledger.
- Closed Shift approval is fail-closed.
- Hosted FIN-P6 regression: PASS and rolled back.
- Final technical verify before checkpoint docs: PASS (73 JS / 142 Python).
- Production automatic deployment remains disabled.

## Historical provenance note

Historical CS-04 through CS-06 managed migration rows remain incomplete although hosted objects are verified. Current Finance migrations are recorded normally.

The original Blueprint v1.0 FINAL LOCK file path referenced by older state files is not present in the working tree. Finance work is reconciled against the authoritative Library/handoff copy; unresolved business rules are not silently invented.

## Source of truth order

1. Blueprint v1.0 FINAL LOCK / authoritative handoff copy
2. Decision / Change Control records
3. docs/checkpoints/PROJECT_STATE.md
4. docs/checkpoints/ROADMAP_PROGRESS.md
5. docs/checkpoints/FIN-P6_CHECKPOINT_REPORT.md
6. docs/checkpoints/FIN-P5_CHECKPOINT_REPORT.md
7. docs/checkpoints/FIN-P4_CHECKPOINT_REPORT.md
8. docs/checkpoints/FIN-P3_CHECKPOINT_REPORT.md
9. docs/checkpoints/FIN-P2B_CHECKPOINT_REPORT.md
10. docs/checkpoints/FIN-P2A_CHECKPOINT_REPORT.md
11. docs/checkpoints/FIN-P1_CHECKPOINT_REPORT.md
12. docs/checkpoints/RELEASE_MANIFEST.json

## NEXT ACTION

FIN-P7 Employee Kasbon Foundation.

Establish a separate employee-Kasbon authority required before cutover. Do not invent payroll deduction, automatic installment, or repayment schedule semantics absent from locked authority.
