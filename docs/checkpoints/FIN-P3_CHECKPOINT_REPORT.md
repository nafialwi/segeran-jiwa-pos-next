# FIN-P3 CHECKPOINT REPORT

Project: segeran-jiwa-pos-next  
Checkpoint: FIN-P3 Customer Debt Foundation  
Date: 2026-09-20  
Branch: work/cs06743-patch3-hardening  
Planning Safepoint: c0c1a61e0beec8c1310599d2b250cb19666fd9a3  
Technical Source Commit: cefe441c8ff4a2f78fe05ed02b92b6f73d975fac  
RLS Hardening Commit: 2345d529e702d83a2ebeaa5ddf25651ca5df40a1  
Status: LOCKED_REMOTE

## Locked business rules

FIN-P3 implements only rules already fixed by Blueprint authority:

- Hutang Pelanggan originates from a sale.
- Partial repayment is supported.
- Debt repayment is not a new sale.
- Balance and repayment history remain traceable.
- Money effects use the single Keuangan authority.
- Customer debt is distinct from employee Kasbon.
- Every completed sale belongs to the actor's Shift Aktual.
- CASH repayment increases Kas Shift.
- TRANSFER repayment increases Bank.
- Business-wide money ledger remains Owner-only.

No due date, aging, credit limit, interest, collection workflow, or employee-Kasbon repayment semantics were invented.

## Data authority

Added:

- `customers`
- `sales.customer_id`
- real FK `sales.shift_id -> shifts.id`
- canonical money account `HUTANG_PELANGGAN`
- immutable `customer_debts`
- immutable `customer_debt_payments`
- derived `customer_debt_balances` security-invoker view

Debt status is derived from immutable facts:

- OPEN
- PARTIAL
- PAID

No mutable debt balance is authoritative.

## Sale-integrity fix-forward

FIN-P3 replaced the historical CS-04 helper implementation without editing historical migrations.

The repaired flow now:

- resolves actor through `profiles.id`, not raw `auth.uid()`;
- computes subtotal before sale insert;
- validates payment only after payment fields are resolved;
- requires actor's open Shift Aktual at the sale location;
- binds `sales.shift_id`;
- requires an active customer for CREDIT;
- aligns one-payment allocation to sale total;
- posts CREDIT to `HUTANG_PELANGGAN`.

The browser-facing atomic RPC is now:

`checkout_sale(operation_id, location_id, items, payment, note)`

Historical private helpers are no longer executable by `authenticated`:

- `private.record_sale`: NOT EXPOSED
- `private.post_sale_transaction`: NOT EXPOSED

## Debt payment authority

`finance_pay_customer_debt(debt_id, method, amount, idempotency_key)`

Behavior:

- requires `CUSTOMER_DEBT_MANAGE`;
- CASH requires actor open shift and posts to `KAS_SHIFT`;
- CASH also writes one `CASH_IN` to the actual shift;
- TRANSFER requires `PAYMENT_TRANSFER` and posts to `BANK`;
- finance movement is TRANSFER from `HUTANG_PELANGGAN`, not INCOME;
- partial payments are valid;
- overpayment is rejected;
- retry is idempotent;
- no repayment creates a new sale.

## RLS fix-forward FIN-P3A

The first hosted behavior regression exposed a real RLS integration gap: security-invoker debt views caused policies to call an internal permission helper that authenticated clients intentionally cannot execute.

FIN-P3A fixed this without granting private-helper access. New debt/customer policies consume `public.get_my_authority()` and its owner/permission snapshot.

Hosted verification confirmed:

- authorized debt manager can read debt projection;
- unauthorized Kasir sees no debt rows;
- Owner can read consolidated debt facts;
- private permission helper remains private.

## Hosted behavior regression

A transaction-scoped hosted regression was executed and rolled back.

Result:

`FIN_P3_HOSTED_REGRESSION_PASS`

Verified end-to-end:

1. Owner creates a minimal customer.
2. Kasir receives explicit CUSTOMER_DEBT_MANAGE and PAYMENT_TRANSFER authority.
3. Shift opens from canonical Kas Utama funding.
4. CREDIT checkout creates exactly one sale.
5. Sale actor is the correct profile.
6. Sale is bound to the actual open shift.
7. Sale subtotal/total is correct before persistence.
8. CREDIT payment allocation equals sale value.
9. One debt-origin INCOME movement increases HUTANG_PELANGGAN.
10. Debt starts OPEN with full balance.
11. Partial CASH repayment reduces debt and increases KAS_SHIFT.
12. CASH repayment increases shift expected cash exactly once.
13. Idempotent retry returns the same repayment.
14. Overpayment is rejected.
15. Partial TRANSFER repayment reduces debt and increases BANK.
16. Unauthorized Kasir cannot read or pay the debt.
17. Owner can see debt and canonical money linkage.
18. Final repayment moves status to PAID and balance to zero.
19. Repayments do not create additional sales.
20. Repayment history remains three immutable payment facts.
21. Sale inventory posting reduces test stock once.
22. All hosted fixtures are rolled back.

## Managed migration evidence

Hosted managed migrations:

- `fin_p3_customer_debt_foundation`
- `fin_p3a_rls_authority_bridge`

Hosted object audit:

- customers: present
- customer_debts: present
- customer_debt_payments: present
- customer_debt_balances: present
- HUTANG_PELANGGAN account: present
- checkout_sale RPC: present
- finance_pay_customer_debt RPC: present

## Advisor disposition

No new checkpoint-owned security ERROR was introduced.

Security WARN for public SECURITY DEFINER RPCs is intentional for authenticated command boundaries; each RPC pins search_path and re-checks current authority, and negative/positive hosted behavior was verified.

Performance advisor reports only unused-index INFO for newly created indexes. No new unindexed-FK finding remains.

## Canonical verification

Final technical gate before checkpoint docs:

- JS: 14 files, 73/73 tests PASS
- Python: 128/128 tests PASS
- format: PASS
- lint: PASS
- typecheck: PASS
- build: PASS
- git diff --check: PASS

## Roadmap accounting

FIN-P3 is a partial finance milestone checkpoint.

Whole-project earned progress remains 78.0%; the 10% finance bucket is not earned until the full finance milestone acceptance gate locks.

## Next action

FIN-P4 - QRIS Settlement & Daily Finance Reconciliation.

This next phase has locked Blueprint semantics and does not require inventing unresolved employee-Kasbon repayment/deduction or month-close/reopen rules.
