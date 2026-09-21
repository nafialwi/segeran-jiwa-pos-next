# HRR-P4 CHECKPOINT REPORT

Project: segeran-jiwa-pos-next
Checkpoint: HRR-P4 Correction / Reversal Closure
Date: 2026-09-21
Branch: work/cs06743-patch3-hardening
Status: LOCKED_REMOTE after final safepoint push

## Blueprint authority

Blueprint v1.0 FINAL LOCK separates Batalkan, Refund/Pengembalian, and Koreksi/Pembalikan.

HRR-P4 closes the distinct Koreksi/Pembalikan authority. The original completed transaction remains intact; correction is represented by linked reversal facts rather than hard-delete or mutation. The UI previews stock, cash/QRIS/transfer, customer debt, HPP/profit, and finance impact before confirmation.

## Technical source safepoints

- HRR-P4 authority implementation: 4e836dd
- HRR-P4 safety hardening: 0e543ab50b66c5dafafabb81d78a3171c76173e5
- Managed migration: hrr_p4_sale_correction

## Implemented contract

HRR-P4 adds:

- immutable public.sale_corrections fact;
- public.sale_correction_preview(uuid) impact preview;
- public.correct_sale(uuid,text,text) idempotent correction command;
- Owner or CORRECTION_LIMITED authorization;
- original sales, sale_items, payments, and customer_debts remain unchanged;
- inventory reversal through the canonical inventory movement writer;
- money reversal through the canonical money movement writer;
- CASH correction through signed negative ADJUSTMENT, not Refund;
- CREDIT correction projection that cancels the effective receivable while preserving original debt facts;
- effective CORRECTED status and correction evidence in History;
- reports distinguish correction events from refunds;
- refund after correction is rejected;
- second distinct correction is rejected;
- same idempotency key replays the same correction fact;
- mobile UI has a distinct Koreksi Transaksi action, impact preview, and explicit confirmation;
- correction is online-only and is never silently queued offline.

## Fail-closed safety boundaries

The locked Blueprint does not define compensation semantics for every downstream historical state. HRR-P4 therefore fails closed instead of inventing rules when:

- the original shift is already CLOSED;
- the original payment shape is not the supported single completed payment;
- a CREDIT sale already has downstream customer-debt payments;
- the canonical source account no longer has enough balance to post the reversal.

Expanding these cases requires an explicit CR/business rule.

## PC verification

Fresh pc-main audit before closure:

- Host: NAFI-ALWI-PC / WSL2
- Branch: work/cs06743-patch3-hardening
- Local HEAD = Remote HEAD = 0e543ab50b66c5dafafabb81d78a3171c76173e5
- Working tree: clean

Canonical verification on pc-main:

- JS: 74/74 PASS
- Python: 199/199 PASS
- format: PASS
- lint: PASS
- typecheck: PASS
- build: PASS
- git diff --check: PASS

## Hosted verification

Managed migration is recorded in hosted Supabase:

- hrr_p4_sale_correction

Hosted rollback regression evidence:

- HRR_P4_HOSTED_CASH_REGRESSION_PASS
- HRR_P4_HOSTED_CREDIT_PERMISSION_PASS
- HRR_P4_HOSTED_TRANSFER_PASS
- HRR_P4_HOSTED_PAID_DEBT_BLOCKER_PASS

Verified behavior includes stock and money reversals, signed cash adjustment semantics, idempotency, History CORRECTED projection, refund-after-correction rejection, immutable correction facts, permission-negative behavior, CREDIT receivable reversal when no downstream payment exists, TRANSFER behavior, and fail-closed handling once downstream debt payment exists.

Post-regression hosted cleanliness was rechecked immediately before closure:

- persisted correction fixtures: 0
- temporary application users: 0
- temporary HRR-P4 operation receipts: 0

## Advisor disposition

No HRR-P4-owned RLS gap is reported for public.sale_corrections.

public.correct_sale and public.sale_correction_preview are authenticated SECURITY DEFINER boundaries by design and enforce authority server-side.

The currently reported anonymous SECURITY DEFINER warnings belong to XP connector v2 RPCs, not HRR-P4, and are carried forward to final security/cutover hardening.

## Verdict

CLEAR.

HRR-P1 Transaction History, HRR-P2 Refund/Reversal, HRR-P3 Reports & Excel, and HRR-P4 Correction/Reversal together satisfy the History, Reversal/Refund, Reports & Excel roadmap bucket.

The 7.0% HRR bucket is earned.

Whole-project earned progress: 95.0%.

## Next action

Attention, Offline, Backup, Health & Cutover Hardening.

The final 5% remains unearned until offline action boundaries, attention/health behavior, backup/restore evidence, global security follow-ups, and cutover acceptance are proven.
