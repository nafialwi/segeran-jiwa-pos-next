# HRR-P1 CHECKPOINT REPORT

Project: segeran-jiwa-pos-next
Checkpoint: HRR-P1 Transaction History Foundation
Date: 2026-09-20
Branch: work/cs06743-patch3-hardening
Status: LOCKED_REMOTE after final safepoint push

## Blueprint authority

Riwayat is an individual transaction search center, not an aggregate report.

Minimum filters:

- date / business day;
- transaction number;
- product;
- user;
- payment method;
- amount;
- status.

The internal transaction ID remains immutable while the user-facing invoice number is searchable.

## Source safepoint

- Technical implementation: 9bfb503d5c804e76bca0834350a88bd92b627757
- Managed migration: hrr_p1_transaction_history

## Implemented contract

HRR-P1 adds:

- HISTORY_OWN permission;
- HISTORY_ALL permission;
- permission-aware transaction_history_search RPC;
- Owner / HISTORY_ALL business-wide scope;
- HISTORY_OWN cashier-only scope;
- all Blueprint minimum filters;
- business_date derived from Shift opening date when available;
- transaction detail including product lines, payments, cashier, customer, location and note;
- /riwayat application route;
- Riwayat navigation card shown only when authority permits access;
- Owner permission-management labels for Riwayat Sendiri / Riwayat Semua.

HRR-P1 is deliberately read-only. It creates no transaction mutation, compensation, or aggregate report authority.

## Verification

Final canonical verification:

- JS: 73/73 PASS
- Python: 176/176 PASS
- format: PASS
- lint: PASS
- typecheck: PASS
- build: PASS
- git diff --check: PASS

## Hosted verification

Managed migration applied successfully:

- hrr_p1_transaction_history

Transaction-scoped hosted regression returned:

HRR_P1_HOSTED_REGRESSION_PASS

Verified and rolled back:

- HISTORY_OWN sees only the caller's transaction;
- another cashier's transaction does not leak;
- combined Blueprint filters return the expected transaction;
- no-history-permission user is denied with HISTORY_READ_REQUIRED;
- HISTORY_ALL sees all business fixture transactions;
- Owner sees all business fixture transactions;
- no fixture identity or sale persisted.

## Advisor disposition

No HRR-P1-owned security ERROR or schema exposure gap was introduced.

transaction_history_search is intentionally an authenticated SECURITY DEFINER RPC because raw sales, payment and identity facts remain closed to direct client reads. The function independently enforces current business authority and HISTORY_OWN/HISTORY_ALL scope.

## Verdict

CLEAR. HRR-P1 Transaction History Foundation is locked.

The History, Reversal/Refund, Reports & Excel 7% roadmap bucket remains unearned until its complete acceptance gate is locked.

Whole-project earned progress remains 88.0%.

## Next action

HRR-P2 Refund authority and implementation design.

The design must preserve the original transaction, explicitly model the three Blueprint stock-impact choices, and reconcile payment/debt/finance effects through canonical engines.
