# FIN-P2B CHECKPOINT REPORT

Project: segeran-jiwa-pos-next  
Checkpoint: FIN-P2B Shift Expense Fact  
Date: 2026-09-20  
Branch: work/cs06743-patch3-hardening  
Planning Safepoint: 7d6b1fd209705a3d25dad6df1337c0f48aabe195  
Technical Source Commit: 21d9ef36cc3e03e52ef71dbbed95138fab988a29  
Index Hardening Commit: 5a4ab5a5a7379cdd392075849b5ab0ca0291e18f  
Status: LOCKED_REMOTE

## Purpose

FIN-P2B implements the locked Shift Expense rule without creating a second finance ledger.

The authority remains:

- Shift is operational context.
- `money_movements` is the canonical money authority.
- a Shift Expense is one business fact, not a duplicate Owner transaction;
- Kasir may create it only with `EXPENSE_SHIFT_CREATE`;
- Kasir reads only own-shift expense context;
- Owner may read consolidated business expense/finance facts.

## Implemented scope

Migrations:

- `20260920160000_fin_p2b_shift_expense.sql`
- `20260920163000_fin_p2b1_expense_index_hardening.sql`

New immutable fact:

- `public.business_expenses`

Each fact retains:

- business;
- location;
- actual shift;
- actor;
- amount;
- category;
- description;
- funding account;
- approval state;
- canonical money movement;
- shift cash transaction;
- timestamp.

New command:

- `finance_post_shift_expense(category, description, amount, idempotency_key)`

The command:

1. resolves current business and actor;
2. requires `EXPENSE_SHIFT_CREATE`;
3. requires a valid open Shift Aktual owned by the actor;
4. resolves canonical `KAS_SHIFT`;
5. requires sufficient canonical shift-cash balance;
6. writes one immutable `EXPENSE` money movement;
7. writes one `CASH_OUT` shift cash transaction;
8. links both to one `business_expenses` fact;
9. records operation receipt and audit event;
10. is idempotent on retry.

## Sale cash alignment

FIN-P2B also aligns canonical cash-sale posting with the finance foundation:

- CASH sale -> `KAS_SHIFT`
- QRIS sale -> `QRIS_BELUM_CAIR`
- TRANSFER sale -> `BANK`

This removes the prior inconsistency where cash-sale finance posting could bypass the canonical Shift cash account.

## Generic cash movement hardening

The old generic `cs05_add_cash_movement` mutation path now fails closed with:

`FINANCE_CASH_MOVEMENT_SOURCE_REQUIRED`

This prevents arbitrary CASH_IN/CASH_OUT from bypassing typed finance facts.

## Read authority

`business_expenses_scope_read` enforces:

- Owner: consolidated business visibility;
- non-Owner: only facts created by that actor and bound to that actor's shift.

`cash_transactions_scope_read` uses the same Owner-or-own-shift boundary.

Global `money_movements` remain Owner-only.

## Hosted behavior regression

A transaction-scoped hosted regression was executed and rolled back.

Verified:

- Kasir without `EXPENSE_SHIFT_CREATE` is denied.
- explicit Kasir permission override enables the typed expense command.
- funded shift opening creates canonical shift cash.
- Shift Expense creates one business expense fact.
- retry with the same idempotency key returns the same expense id.
- one linked `EXPENSE` money movement is funded by `KAS_SHIFT`.
- one linked `CASH_OUT` is recorded on the actual shift.
- expected shift cash decreases exactly once.
- expense greater than canonical shift-cash balance is rejected.
- generic cash movement path is fail-closed.
- another Kasir cannot read the first Kasir's expense.
- Owner can read the consolidated expense and finance linkage.
- all hosted test facts were rolled back.

Result: `FIN_P2B_HOSTED_REGRESSION_PASS`.

## Performance hardening

Hosted advisor initially found two new unindexed foreign keys on `business_expenses`:

- `location_id`
- `funding_account_id`

FIN-P2B1 added covering indexes for both. Re-check confirmed both unindexed-FK findings are gone. Remaining unused-index INFO is expected for newly created indexes with no production traffic.

## Canonical verification

Final pre-checkpoint command: `npm run verify`  
Result: CLEAR

- JS: 14 files, 73/73 tests PASS
- Python: 123/123 tests PASS
- format: PASS
- lint: PASS
- typecheck: PASS
- build: PASS
- git diff --check: PASS

## Hosted migration evidence

Managed migrations applied successfully:

- `fin_p2b_shift_expense`
- `fin_p2b1_expense_index_hardening`

No new Supabase security ERROR was introduced. Public SECURITY DEFINER RPC warnings are reviewed as API-boundary warnings; this checkpoint relies on pinned search paths plus explicit session/business/permission checks and hosted negative/positive behavior tests.

## Roadmap accounting

FIN-P2B is a partial finance milestone checkpoint. No partial roadmap weight is invented.

Whole-project earned progress remains 78.0%.

## Next action

FIN-P3 - Customer Debt Foundation.

Locked rules for FIN-P3:

- Hutang Pelanggan originates from a sale.
- partial repayment is supported.
- debt repayment is not a new sale.
- balance/history must remain traceable.
- money effects must continue through the single finance authority.

Do not implement unresolved employee Kasbon repayment/deduction semantics or month-close/reopen rules until their authority is explicitly locked.
