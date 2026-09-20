# HRR-P2 CHECKPOINT REPORT

Project: segeran-jiwa-pos-next
Checkpoint: HRR-P2 Sale Refund / Reversal Authority
Date: 2026-09-20
Branch: work/cs06743-patch3-hardening
Status: LOCKED_REMOTE after final safepoint push

## Blueprint authority

HRR-P2 implements full-sale Refund/Pengembalian for a completed valid sale while preserving the original sale and payment facts.

The Blueprint stock-impact choices are explicit:

- RETURN_TO_STOCK — returned sellable goods reverse the original tracked stock consumption.
- DAMAGED_UNFIT — damaged/unfit returned goods do not increase sellable stock.
- NO_GOODS_RETURNED — no goods are returned and sellable stock does not increase.

Before confirmation, the UI explains stock, cash/transfer, customer-debt, HPP/reporting, and finance impact.

Partial refund is not introduced because it is not defined by the locked Blueprint.

## Source safepoint

- Technical implementation: dd997dd63f54e41f844f20b6cd5ed7fbf6854e35
- Managed migration: hrr_p2_sale_refund

## Implemented contract

HRR-P2 adds:

- immutable public.sale_refunds fact;
- public.refund_sale authenticated command boundary;
- Owner or CORRECTION_LIMITED authorization;
- one-refund-per-sale fail-closed rule;
- idempotent retry through canonical operation receipts;
- canonical inventory reversal for RETURN_TO_STOCK;
- no sellable-stock restoration for DAMAGED_UNFIT / NO_GOODS_RETURNED;
- canonical money REVERSAL posting for payout;
- Shift REFUND cash transaction for cash payout;
- transfer payout through BANK with balance guard;
- customer-debt refund projection that preserves original debt/payment facts;
- partial-paid CREDIT sale handling: paid amount is returned and unpaid receivable is cancelled;
- effective REFUNDED status in transaction history without mutating public.sales;
- refund detail in Riwayat;
- permission-gated Refund Transaksi UI;
- explicit QRIS note: provider transaction is not automatically cancelled; payout is explicit CASH or TRANSFER.

Completed sales, payments, customer debts, inventory movements and money movements remain immutable original facts.

## Verification

Final canonical verification:

- JS: 73/73 PASS
- Python: 181/181 PASS
- format: PASS
- lint: PASS
- typecheck: PASS
- build: PASS
- git diff --check: PASS

## Hosted verification

Managed migration applied successfully:

- hrr_p2_sale_refund

Transaction-scoped hosted rollback regression returned:

HRR_P2_HOSTED_REGRESSION_PASS

Verified and rolled back:

- CASH refund + RETURN_TO_STOCK restores tracked stock;
- CASH refund creates Shift REFUND and returns expected cash to its pre-fixture value;
- original sale remains COMPLETED;
- original payment remains PAID;
- history shows effective REFUNDED plus refund detail;
- same idempotency key replays one refund fact;
- second refund is rejected;
- TRANSFER refund + DAMAGED_UNFIT does not restore sellable stock;
- BANK balance returns to its pre-fixture value after sale + refund;
- CREDIT partial payment refund returns the paid amount and cancels only the remaining receivable;
- original customer debt and payment facts remain intact;
- customer-debt projection becomes REFUNDED with zero effective balance;
- user without CORRECTION_LIMITED is denied;
- sale_refunds UPDATE is blocked by immutable-fact trigger;
- no regression fixture persists.

Post-regression cleanliness:

- test refunds: 0
- temporary users: 0
- temporary operation receipts: 0
- real Owner shift remains OPEN
- real expected cash remains Rp17.000

## Advisor disposition

No HRR-P2-owned RLS gap was introduced on sale_refunds.

The advisor reports authenticated SECURITY DEFINER RPCs, including refund_sale. This is intentional: raw fact tables remain closed to direct client mutation/read paths, the public command pins search_path='', resolves current authority server-side, and explicitly requires Owner or CORRECTION_LIMITED. Permission-negative hosted behavior was tested.

Unused-index findings are informational on the newly created low-volume refund indexes and are not a correctness blocker.

## Verdict

CLEAR. HRR-P2 Sale Refund / Reversal Authority is locked.

The History, Reversal/Refund, Reports & Excel 7% roadmap bucket remains unearned until the complete bucket acceptance gate is locked.

Whole-project earned progress remains 88.0%.

## Next action

HRR-P3 Reports & Excel Foundation.

Build reports only from canonical facts/projections. Minimum Owner reports are Penjualan, Produk, Persediaan, Shift, Pembelian and Keuangan. Excel must be presentation-ready rather than a raw dump.
