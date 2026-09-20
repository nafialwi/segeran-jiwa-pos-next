# HRR-P2 Sale Refund Design

Date: 2026-09-20
Blueprint baseline: v1.0 FINAL LOCK
Status: IMPLEMENTATION-BOUND DESIGN

## Locked semantics

Refund is distinct from pre-completion cancellation and from correction/reversal of an incorrectly saved transaction.

The original completed sale must remain intact. Refund is a new immutable fact linked to that sale.

HRR-P2 implements full-sale refund only. Partial refund is not defined by the locked Blueprint and is not introduced here.

## Non-Owner authority

Owner is always allowed.

The existing CORRECTION_LIMITED permission is the bounded non-Owner authority for Refund/Koreksi business actions. HRR-P2 does not invent a second refund-specific permission.

## Stock disposition

Every refund records exactly one Blueprint disposition:

- RETURN_TO_STOCK: reverse the original SALE inventory movement and restore tracked quantity at the original sale location.
- DAMAGED_UNFIT: do not increase saleable inventory; record the disposition in the Refund fact.
- NO_GOODS_RETURNED: do not increase inventory; record the disposition in the Refund fact.

The original inventory movement is never edited.

## Refund funding

The system records how money is actually returned to the customer now:

- CASH: payout from KAS_SHIFT and create a REFUND cash transaction in the actor's current OPEN shift at the sale location.
- TRANSFER: payout from BANK.
- NONE: allowed only for an unpaid CREDIT sale where no money has been collected.

QRIS is manual in this product. HRR-P2 does not pretend to cancel a provider transaction. A QRIS-origin sale may be refunded by an explicit CASH or TRANSFER payout while its provider receivable continues through normal settlement.

## Customer debt

For CREDIT sales:

- sale_refund payout_amount equals debt payments already collected;
- receivable_cancelled_amount equals the remaining unpaid balance;
- if payout_amount is positive, CASH or TRANSFER is required;
- if payout_amount is zero, refund_method is NONE;
- the customer-debt projection becomes REFUNDED with balance zero;
- historical debt payment facts remain intact.

The refund therefore preserves the history of what was paid while compensating the remaining receivable and any money returned to the customer.

## Money engine

All financial effects use public.money_movements.

- payout to customer is REVERSAL from the actual current source account;
- remaining CREDIT receivable cancellation is REVERSAL from HUTANG_PELANGGAN;
- no refund is classified as a new operating EXPENSE.

## HPP / reporting

HRR-P2 records stock disposition so the future report engine can treat returned-to-stock versus damaged/no-return goods differently. HRR-P2 does not invent final HPP reporting calculations.

## Idempotency and immutability

- one Refund fact per sale;
- command is idempotent;
- Refund fact is immutable;
- original sale, payment, debt, inventory and money facts are never updated or deleted.
