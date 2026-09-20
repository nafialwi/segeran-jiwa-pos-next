# FIN-P2B Shift Expense Fact Design

**Date:** 2026-09-20  
**Baseline:** FIN-P2A LOCKED_REMOTE at a0c94005ef5735d4e4aeb1636528e0496cc73f35

## Goal

Create one authoritative business-expense fact that is simultaneously linked to Shift, cash projection, canonical finance ledger, and activity/audit evidence, without duplicating the transaction for Owner.

## Locked authority

- Keuangan is the single money authority.
- Shift is operational context, not a second money ledger.
- Kasir may record Shift Expense only when `EXPENSE_SHIFT_CREATE` is granted.
- Owner can see consolidated expense facts.
- Kasir may only see expense facts from their own actual shift.
- One input must connect Shift, Kas, Keuangan, Laporan, and Aktivitas.
- Expense data must retain amount, category, description, timestamp, actor, actual shift, funding account/source, and approval state where applicable.
- CASH sales belong to Kas Shift.
- Approval-by-threshold/category is supported conceptually but its detailed configuration is not yet locked; FIN-P2B therefore records `NOT_REQUIRED` and does not invent approval thresholds.

## Scope

### Cash sale account alignment

Fix-forward `private.post_sale_transaction` so:

- CASH -> `KAS_SHIFT`
- QRIS -> `QRIS_BELUM_CAIR`
- TRANSFER -> `BANK`

The function body is derived from the existing canonical source and changes only the CASH account mapping.

### Business expense fact

Create immutable `public.business_expenses` with:

- id
- business_id
- location_id
- shift_id
- actor_profile_id
- amount
- category_code
- description
- funding_account_id
- approval_state
- money_movement_id
- cash_transaction_id
- created_at

FIN-P2B writes `approval_state='NOT_REQUIRED'`.

### Read authority

`business_expenses` SELECT:

- Owner: all expenses in the business.
- non-Owner: only rows whose shift belongs to the current profile.

Direct INSERT/UPDATE/DELETE remains revoked.

### Command

Add:
`finance_post_shift_expense(category_code, description, amount, idempotency_key)`

Rules:

1. current session/business must be active;
2. actor must have `EXPENSE_SHIFT_CREATE`;
3. actor must own one OPEN shift;
4. active funding account is `KAS_SHIFT`;
5. canonical KAS_SHIFT balance must cover amount;
6. command is idempotent;
7. create one EXPENSE money movement from KAS_SHIFT;
8. create one CASH_OUT cash transaction for expected-drawer reconciliation;
9. create one immutable business-expense fact linking both records;
10. create activity/audit evidence;
11. replay returns the same expense and creates no duplicate.

### Generic cash-movement bypass

The old `cs05_add_cash_movement` command is retained for compatibility at the SQL signature level but fails closed with:
`FINANCE_CASH_MOVEMENT_SOURCE_REQUIRED`.

The old generic Shift UI form is removed. Future CASH_IN/ADJUSTMENT flows must receive an explicit finance source design before being re-enabled.

### UI

When an active shift exists and current authority contains `EXPENSE_SHIFT_CREATE`:

- show Catat Pengeluaran Shift;
- collect category, description, amount;
- post through `finance_post_shift_expense`;
- show expense rows for the current shift.

Users without permission do not see the input; server authorization remains authoritative.

## Deferred

- threshold/category approval configuration and approval transition engine;
- Owner personal expense, already handled by FIN-P1;
- customer debt;
- employee Kasbon;
- QRIS settlement fee;
- month close/reopen;
- report/export UX.

## Acceptance

- future CASH sale finance movement lands in KAS_SHIFT;
- generic cash movement command is fail-closed;
- unpermitted Kasir cannot post expense;
- permitted Kasir can post only against own OPEN shift;
- one business fact, one EXPENSE movement, one CASH_OUT row;
- replay is idempotent;
- insufficient KAS_SHIFT balance is atomic failure;
- Owner can read fact; other Kasir cannot read another actor's expense;
- expected drawer cash decreases by expense amount;
- full local verify PASS;
- hosted regression PASS and rolled back;
- final checkpoint committed and pushed.
