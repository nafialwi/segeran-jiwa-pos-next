# FIN-P5 Supplier Payable Foundation Design

**Date:** 2026-09-20

## Authority

Blueprint v1.0 FINAL LOCK requires:

- purchase flow ends in Pay / Supplier Payable -> Finance;
- purchase payment may be cash, transfer, or payable according to permission;
- Supplier Payable supports partial payment;
- supplier returns later reduce stock and correct payable/refund according to the actual return condition;
- Supplier Payable is part of the minimum finance account set;
- Kasir must not receive global Supplier Payable visibility.

## Scope

FIN-P5 establishes the supplier payable finance foundation only:

1. canonical UTANG_PEMASOK money account;
2. immutable supplier payable fact tied to a POSTED goods receipt and its purchase order/supplier;
3. immutable partial-payment facts;
4. derived balance/status view;
5. canonical money movements for liability creation and payment;
6. permission-bounded authenticated commands;
7. RLS that keeps global supplier debt out of ordinary Kasir access.

Supplier-return inventory/refund correction is intentionally a later bounded phase because the current repository has no canonical supplier-return stock command.

## Money semantics

The existing money engine is the only money authority.

- New payable: ADJUSTMENT from UTANG_PEMASOK to outside the account set. This makes the liability account balance negative.
- Payment: TRANSFER from KAS_UTAMA or BANK to UTANG_PEMASOK. This decreases cash/bank and moves the liability balance toward zero.
- Payment is not INCOME and is not recorded as a new operating EXPENSE.
- KAS_UTAMA payment is the CASH path.
- BANK payment requires PAYMENT_TRANSFER in addition to PURCHASE_MANAGE.

## Payable amount

FIN-P5 does not derive invoice amount from partial GRN quantity because Blueprint does not lock discount/tax/freight allocation semantics for partial receipts. The payable amount is entered explicitly from the supplier invoice and must reference a POSTED goods receipt.

## Authority

- create/pay: PURCHASE_MANAGE;
- BANK payment additionally requires PAYMENT_TRANSFER;
- read: Owner or PURCHASE_MANAGE;
- direct table writes denied to clients;
- command RPCs are SECURITY DEFINER with empty search_path and internal permission checks.

## Idempotency and immutability

Both create and pay commands use operation locks and canonical record_money_movement. Facts are append-only. Overpayment is rejected.

## Deferred

- supplier return stock + payable/refund correction;
- invoice allocation rules across partial receipts;
- due-date/aging rules not present in final locked Blueprint.
