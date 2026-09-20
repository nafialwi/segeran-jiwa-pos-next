# HRR-P4 Sale Correction / Reversal Closure Design

Date: 2026-09-21
Blueprint baseline: v1.0 FINAL LOCK
Classification: BUG / CR closure of an already-required Blueprint authority
Status: RED / implementation pending

## Blueprint contract

Blueprint section 14 defines three different concepts:

- Batalkan: before a transaction is completed.
- Refund/Pengembalian: a valid completed transaction is later returned.
- Koreksi/Pembalikan: a stored transaction is wrong and must be reversed.

Koreksi therefore MUST NOT call or masquerade as Refund. The original transaction remains immutable and auditable. Correction creates compensating facts linked to the original sale and its canonical inventory/money movements.

Before confirmation the application must explain the effect on stock, cash/QRIS/transfer, customer debt, HPP, and Finance.

## Authority and permission

- Owner may correct.
- Non-owner requires explicit CORRECTION_LIMITED.
- Direct table mutation remains unavailable.
- Correction is an idempotent command.
- A sale already refunded or corrected cannot be corrected again.
- A corrected sale cannot later be refunded.

## Canonical reversal model

Correction creates an immutable sale_corrections fact. It never updates or deletes sales, sale_items, payments, customer_debts, inventory_movements, or money_movements.

### Inventory

The complete tracked-stock effect of the original SALE movement is reversed through private.record_inventory_movement with reverses_movement_id pointing to the original SALE inventory movement.

### Money

The original sale money movement is reversed through private.record_money_movement with reverses_movement_id pointing to the original movement.

- CASH: reverse KAS_SHIFT income.
- QRIS: reverse QRIS_BELUM_CAIR income.
- TRANSFER: reverse BANK income.
- CREDIT: reverse HUTANG_PELANGGAN receivable income.

This is an accounting correction, not a customer payout and not an expense.

### Shift cash

CASH payment insertion originally creates cash_transactions.SALE automatically. Correction must not create cash_transactions.REFUND because no customer refund occurred.

cash_transactions.ADJUSTMENT is hardened to allow a signed non-zero amount while all other cash transaction types stay strictly positive. CASH correction inserts a negative ADJUSTMENT on the original shift, linked to SALE_CORRECTION. cs05_shift_expected_cash already includes signed ADJUSTMENT, so expected cash is corrected without introducing a second cash engine.

### Customer debt

An unpaid CREDIT sale can be corrected by reversing its receivable.

If any customer_debt_payment already exists, correction fails closed with SALE_CORRECTION_PAID_DEBT_UNSUPPORTED. Blueprint does not define how historical debt payments should be reallocated to a replacement transaction, so HRR-P4 must not invent that rule.

### HPP

Canonical transaction-level HPP is not complete. Preview/reporting must say HPP impact is unavailable rather than assume zero or fabricate profit.

## History and reports

History exposes CORRECTED as distinct from REFUNDED and includes the correction fact/reversal references.

Sales/Product/Finance reports treat a correction as a separate negative event on correction date, preserving the original event. Net figures subtract both refunds and corrections without rewriting original sales.

Shift reporting keeps Refund and Correction separate: Refund remains REFUND; correction changes expected cash through signed ADJUSTMENT.

## UI

Riwayat remains the single authority page.

For an eligible COMPLETED sale, users with authority see two distinct actions:

- Refund Transaksi
- Koreksi Transaksi

Koreksi has its own confirmation surface and must explicitly show:

- Dampak Stok
- Dampak Kas / QRIS / Transfer
- Dampak Hutang
- Dampak HPP / Laba
- Dampak Keuangan

The copy must state that Koreksi is not a customer refund and the original transaction remains intact.

## Change-control impact matrix

- UI: distinct Koreksi action + preview; no duplicate authority page.
- Permission: Owner or CORRECTION_LIMITED.
- Database: immutable correction fact + forward-only constraint/view/RPC changes.
- Finance: canonical money REVERSAL only; not expense/refund.
- Inventory: canonical inventory reversal only.
- Reports: explicit correction event and net effect.
- Offline: sensitive correction command is online-only for this milestone; no offline queue semantics are invented.
- Migration: forward-only, source controlled, hosted regression required.
- Rollback/recovery: migration is additive; business facts immutable; all acceptance fixtures run transactionally and roll back.
- Acceptance: source verify + hosted behavior regression + cleanup proof.

## Acceptance boundary

HRR-P4 closes only when:

1. original sale/payment/item/debt facts remain unchanged;
2. stock and money reverse via canonical writers;
3. CASH expected cash is restored by signed ADJUSTMENT, not Refund;
4. CREDIT with downstream payments fails closed;
5. idempotent replay returns the same correction and conflicting replay fails;
6. permission-negative access fails;
7. History exposes CORRECTED separately from REFUNDED;
8. reports subtract correction events without erasing originals;
9. UI preview contains all Blueprint impact categories;
10. hosted rollback leaves no fixture residue.
