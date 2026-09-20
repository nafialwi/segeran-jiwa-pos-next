# PROJECT STATE - FIN-P3 LOCKED_REMOTE

## Canonical identity

- Workspace: Segeran Jiwa Next Vol. 1
- Product: Segeran Jiwa POS Next
- Blueprint: v1.0 FINAL LOCK
- Current milestone: FIN-P3 - Customer Debt Foundation - LOCKED_REMOTE
- Current branch: work/cs06743-patch3-hardening
- FIN-P3 planning source: c0c1a61e0beec8c1310599d2b250cb19666fd9a3
- FIN-P3 technical source: cefe441c8ff4a2f78fe05ed02b92b6f73d975fac
- FIN-P3 RLS hardening: 2345d529e702d83a2ebeaa5ddf25651ca5df40a1
- Managed hosted migrations: fin_p3_customer_debt_foundation; fin_p3a_rls_authority_bridge
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
- Finance milestone: IN PROGRESS; FIN-P1, FIN-P2A, FIN-P2B, and FIN-P3 locked
- Whole-project weighted progress: 78.0%

The finance roadmap bucket remains unearned until the complete finance milestone acceptance gate is locked.

## Current verified state

- FIN-P1 finance foundation is locked.
- FIN-P2A explicit Shift funding bridge is locked.
- FIN-P2B typed Shift Expense is locked.
- FIN-P3 Customer Debt Foundation is locked.
- Hutang Pelanggan is a canonical receivable account and immutable debt fact, not a parallel money ledger.
- CREDIT sale is bound to customer, correct profile actor, and actual open shift.
- Sale subtotal is computed before persistence.
- Customer debt repayments support partial CASH/TRANSFER payments.
- Debt repayment transfers receivable into KAS_SHIFT or BANK and never creates a new sale.
- CASH debt repayment is reflected in the actor's actual shift cash reconciliation.
- Debt history/status is derived from immutable origin/payment facts.
- Unauthorized Kasir debt reads fail closed; Owner can read consolidated debt and money linkage.
- Historical private sale helpers are no longer executable by authenticated clients.
- FIN-P3A RLS uses the public authority boundary rather than exposing internal permission helpers.
- Hosted end-to-end regression: PASS and rolled back.
- Final technical canonical verify: PASS (73 JS / 128 Python).
- Production automatic deployment remains disabled.

## Historical provenance note

The hosted Supabase migration-history table does not list every historical CS-04 through CS-06 source migration although their hosted objects are present. Current finance migrations are recorded normally in managed migration history.

The original Blueprint v1.0 FINAL LOCK path referenced by older state files is not present in the current working tree. Finance implementation is reconciled against the authoritative one-file handoff snapshot; no unresolved Blueprint rule is silently invented.

## Source of truth order

1. Blueprint v1.0 FINAL LOCK / authoritative handoff snapshot
2. Decision / Change Control records
3. docs/checkpoints/PROJECT_STATE.md
4. docs/checkpoints/ROADMAP_PROGRESS.md
5. docs/checkpoints/FIN-P3_CHECKPOINT_REPORT.md
6. docs/checkpoints/FIN-P2B_CHECKPOINT_REPORT.md
7. docs/checkpoints/FIN-P2A_CHECKPOINT_REPORT.md
8. docs/checkpoints/FIN-P1_CHECKPOINT_REPORT.md
9. docs/superpowers/specs/2026-09-20-fin-p3-customer-debt-foundation-design.md
10. docs/checkpoints/RELEASE_MANIFEST.json

## NEXT ACTION

FIN-P4 - QRIS Settlement & Daily Finance Reconciliation.

Do not implement unresolved employee-Kasbon repayment/deduction or month-close/reopen semantics until their authority is explicitly locked.
