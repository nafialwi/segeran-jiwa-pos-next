# FIN-P1 Finance Foundation Design

**Date:** 2026-09-20  
**Project:** Segeran Jiwa POS Next  
**Authority:** Blueprint v1.0 FINAL LOCK, finance sections preserved in `SJPOS_NEXT_ONE_FILE_HANDOFF_ALL_AUTHORITIES_2026-09-08.md`.

## Goal

Establish the secure canonical finance foundation without creating a second money ledger and without implementing blueprint details that remain intentionally unresolved.

## Locked business rules

- Keuangan is the only authority for money balances/movements.
- Shift is operational context, not a second money ledger.
- Kas Utama -> Kas Shift and other internal transfers are transfers, not income/expense.
- QRIS received is not cash before settlement.
- Pengeluaran Pribadi is Owner-only, reduces business assets, and is not an operating expense/profit cost.
- Kasir must not receive business-wide finance, Bank balance, capital, global profit, or month-close access.
- There is no separate Admin role.
- Direct UI hiding is not authorization; database/RPC authority is fail-closed.

## Existing primitives reused

FIN-P1 reuses:

- `public.money_accounts`
- `public.money_movements`
- `public.money_balances`
- `private.record_money_movement(...)`
- operation receipt / audit idempotency
- CS-03 `private.is_owner(...)` authority

No second ledger is introduced.

## Scope

### 1. Canonical Kas Shift account

Add one business-level `KAS_SHIFT` money account.

This is an aggregate finance account. Individual Shift Aktual detail remains in `cash_transactions`; FIN-P1 does not turn `cash_transactions` into a second balance authority.

### 2. Owner-only finance read boundary

Replace broad active-member SELECT policies for:

- `money_accounts`
- `money_movements`

with Owner-only policies.

`money_balances` already uses `security_invoker=true`, therefore it inherits the tightened base-table RLS.

### 3. Internal money transfer RPC

Add `finance_post_transfer(...)`.

Rules:

- Owner-only.
- Same business and active accounts.
- from != to.
- amount > 0.
- source balance must be sufficient.
- movement type = `TRANSFER`.
- idempotent through the existing money movement engine.
- no direct table DML by client.

### 4. Owner capital contribution RPC

Add `finance_post_owner_capital(...)`.

Rules:

- Owner-only.
- destination is an active business money account.
- amount > 0.
- use movement type `ADJUSTMENT`, not `INCOME`, so capital injection is not operating income.
- source type / reason code = `OWNER_CAPITAL`.
- idempotent.

### 5. Owner personal withdrawal RPC

Add `finance_post_owner_personal_withdrawal(...)`.

Rules:

- Owner-only.
- amount > 0.
- source balance must be sufficient.
- movement type = `ADJUSTMENT`, not `EXPENSE`.
- source type / reason code = `OWNER_PERSONAL_EXPENSE`.
- this preserves the locked rule that Pengeluaran Pribadi is not operating expense/profit cost.
- idempotent.

## Explicitly deferred

FIN-P1 does not yet implement:

- business/shift expense facts and approval policy (FIN-P2);
- customer debt payment engine (later finance phase);
- employee Kasbon repayment/deduction mechanics, because the blueprint explicitly leaves that detail for later authority;
- QRIS provider settlement fee detail beyond the existing locked direction;
- month close/reopen, because the blueprint explicitly leaves its detailed authority for the final finance design;
- finance reports/Excel, which remain a later roadmap milestone.

## Security

- authenticated users keep SQL SELECT grants only where needed, but RLS is Owner-only.
- RPCs are `SECURITY DEFINER`, `search_path=''`, and independently check Owner authority.
- private helpers remain non-client-executable.
- direct INSERT/UPDATE/DELETE on canonical money movement facts remains revoked.

## Acceptance

FIN-P1 is clear only when:

1. source regression proves KAS_SHIFT seed exists;
2. Kasir direct finance reads are denied by policy;
3. Owner finance reads are allowed;
4. transfer posts exactly one canonical movement and replay does not duplicate;
5. insufficient balance transfer is rejected;
6. Owner capital increases balance but is not movement_type INCOME;
7. Owner personal withdrawal decreases balance but is not movement_type EXPENSE;
8. non-Owner RPC calls are denied;
9. full canonical `npm run verify` passes;
10. hosted migration is applied and verified;
11. checkpoint evidence is committed and pushed to the active GitHub branch.
