# FIN-P3 Customer Debt Foundation Design

**Date:** 2026-09-20  
**Status:** LOCKED FOR IMPLEMENTATION  
**Baseline:** FIN-P2B LOCKED_REMOTE at e3697ec99136849d17279838eb50aa107c0697a1

## Authority

This design is constrained by Blueprint v1.0 FINAL LOCK / authoritative handoff:

- Hutang Pelanggan originates from a sale.
- Partial repayment is supported.
- Debt repayment is not a new sale.
- Debt balance/history must remain traceable.
- Payment and debt feed the single Keuangan money authority.
- Customer debt is distinct from employee Kasbon.
- Every completed sale belongs to the actor's Shift Aktual.
- Cash received belongs to Kas Shift; transfer belongs to Bank.
- Business-wide finance remains Owner-only.
- Customer/debt actions are permission-gated.

## Existing defects repaired in this checkpoint

The historical CS-04 `private.record_sale` source currently:

- validates payment variables before assigning them;
- inserts the sale before calculating subtotal;
- writes `auth.uid()` into columns that reference `profiles.id`;
- does not bind the created sale to the actor's active Shift Aktual.

FIN-P3 must fix these without rewriting historical migrations.

## Data model

### customers

Minimum master only:

- id
- business_id
- display_name
- phone nullable
- active
- created_by
- created_at
- updated_at

No credit limit, due date, address, aging, interest, or collection policy is invented.

### sales.customer_id

Nullable for normal sales. Required for CREDIT.

`sales.shift_id` receives a real FK to `shifts`; new checkout writes the actual open shift.

### money account

Seed one canonical account:

- code: HUTANG_PELANGGAN
- display: Hutang Pelanggan
- type: OTHER

A credit sale increases this receivable account. Repayment transfers value out of it into the actual received-money account. Repayment therefore does not create new income.

### customer_debts

One immutable debt-origin fact per credit sale:

- business_id
- customer_id
- sale_id unique
- original_amount
- receivable_movement_id unique
- created_by
- created_at

### customer_debt_payments

One immutable repayment fact:

- business_id
- debt_id
- customer_id
- actor_profile_id
- method: CASH or TRANSFER
- amount
- destination_account_id
- shift_id nullable
- cash_transaction_id nullable
- money_movement_id unique
- created_at

Cash repayment requires the actor's open shift and creates a CASH_IN. Transfer repayment goes to BANK and remains subject to PAYMENT_TRANSFER authority.

### customer_debt_balances

security_invoker view deriving:

- original amount
- paid amount
- remaining balance
- OPEN / PARTIAL / PAID

No mutable balance/status column is authoritative.

## Commands

### save_customer

Requires CUSTOMER_MANAGE. Creates or edits minimum customer metadata within the current business.

### checkout_sale

New public atomic command wrapping repaired private sale creation + posting.

It:

1. resolves current business/profile from authenticated authority;
2. requires SALE_EXECUTE;
3. requires an open Shift Aktual owned by actor at selected location;
4. computes subtotal before writing sale;
5. stores actor profile id, never auth user id, in profile FK columns;
6. validates one payment allocation;
7. for CREDIT, requires CUSTOMER_DEBT_MANAGE and an active customer;
8. creates sale/items/payment;
9. posts stock and money/debt facts;
10. is idempotent.

Initial checkout remains one payment allocation. Split-payment architecture is not expanded in FIN-P3.

### finance_pay_customer_debt

Requires CUSTOMER_DEBT_MANAGE.

- CASH -> KAS_SHIFT, requires actor open shift, creates CASH_IN.
- TRANSFER -> BANK, requires PAYMENT_TRANSFER.
- records one TRANSFER money movement from HUTANG_PELANGGAN to destination.
- rejects amount <= 0 and overpayment.
- supports partial payments.
- idempotent retry returns same repayment fact.
- never creates a sale.

## Posting behavior

Normal methods remain:

- CASH -> KAS_SHIFT
- QRIS -> QRIS_BELUM_CAIR
- TRANSFER -> BANK

CREDIT:

- requires sale.customer_id;
- posts INCOME to HUTANG_PELANGGAN as the receivable created by the sale;
- creates exactly one customer_debts fact;
- does not create CASH_IN/CASH_OUT.

## Security

- customer master read: Owner or CUSTOMER_MANAGE or CUSTOMER_DEBT_MANAGE.
- debt/payment read: Owner or CUSTOMER_DEBT_MANAGE.
- direct writes revoked; commands are authority.
- money ledger remains Owner-only.
- private sale helpers are not the intended browser API.
- public command RPCs pin search_path and re-check current authority.

## Explicit non-goals

- employee Kasbon;
- debt due dates / aging;
- credit limits;
- interest/penalties;
- collections workflow;
- split-payment UI;
- refund/reversal integration;
- month close/reopen;
- offline debt mutation.

Those need later authority or milestone scope.
