# FIN-P4 CHECKPOINT REPORT

Project: segeran-jiwa-pos-next  
Checkpoint: FIN-P4 QRIS Settlement & Daily Finance Reconciliation  
Date: 2026-09-20  
Branch: work/cs06743-patch3-hardening  
Planning Safepoint: bea7a63cfeab8d07ef6545ec72037ad59901e9f0  
Technical Source Commit: 516c896fb4eaf9311e5cb3c6de52267cbfd393e3  
Status: LOCKED_REMOTE

## Locked business rules

FIN-P4 implements Blueprint rules without creating a second finance ledger:

- QRIS received is not cash.
- QRIS sale money belongs to QRIS Belum Cair until settlement.
- Pencairan moves QRIS Belum Cair -> QRIS Sudah Cair -> Bank.
- MDR/provider fee is a finance expense and never rewrites sale revenue.
- Internal account transfers are not new income.
- Daily reconciliation checks cash, QRIS, transfer, and stock status when available.
- Reconciliation result is SESUAI or PERLU_DIPERIKSA.
- Global finance and reconciliation are Owner-only.

## QRIS settlement authority

Added immutable `qris_settlements`.

`finance_settle_qris(settlement_date, provider_reference, gross_amount, provider_fee, idempotency_key)`:

1. resolves current business/actor from authority;
2. requires Owner;
3. checks QRIS Belum Cair balance;
4. moves gross amount QRIS_BELUM_CAIR -> QRIS_SUDAH_CAIR as SETTLEMENT;
5. records MDR/provider fee as EXPENSE from QRIS_SUDAH_CAIR when fee > 0;
6. transfers net QRIS_SUDAH_CAIR -> BANK;
7. records one immutable settlement fact;
8. records operation receipt and audit event;
9. is idempotent.

Sale revenue remains untouched.

## Daily finance reconciliation

Added immutable `finance_daily_reconciliations`.

`finance_reconcile_day(business_date, counted_cash, bank_transfer_received, stock_status, idempotency_key)` snapshots:

- expected business cash as-of the end of the selected date;
- counted cash;
- cash variance;
- QRIS sale amount recorded for the date;
- gross QRIS settlements for the date;
- QRIS variance;
- transfer-method sale amount recorded for the date;
- actual transfer received input;
- transfer variance;
- stock status: SESUAI / PERLU_DIPERIKSA / NOT_CHECKED;
- overall result: SESUAI / PERLU_DIPERIKSA.

The snapshot is immutable, so later money movement does not rewrite historical reconciliation evidence.

## Hosted behavior regression

Transaction-scoped hosted regression result:

`FIN_P4_HOSTED_REGRESSION_PASS`

All fixtures were rolled back.

Verified:

1. non-Owner QRIS settlement is denied;
2. non-Owner cannot read settlement facts;
3. QRIS settlement with zero fee works;
4. retry with same idempotency key returns the same settlement;
5. settlement with MDR/provider fee works;
6. gross settlement clears the seeded QRIS Belum Cair amount exactly;
7. QRIS Sudah Cair staging returns to its baseline after fee + bank transfer;
8. Bank receives net QRIS amount;
9. provider fee creates one EXPENSE movement;
10. total INCOME remains sale income only; settlement does not rewrite revenue;
11. settlement above available QRIS balance is rejected;
12. exact cash/QRIS/transfer snapshot yields SESUAI;
13. cash/stock discrepancy yields PERLU_DIPERIKSA;
14. non-Owner cannot read daily finance reconciliation;
15. non-Owner cannot execute daily finance reconciliation.

## Hosted migration evidence

Managed migration:

- `fin_p4_qris_settlement_reconciliation`

Hosted advisor disposition:

- no checkpoint-owned security ERROR;
- public finance command RPCs produce expected SECURITY DEFINER WARN because they are authenticated command boundaries;
- both commands pin search_path and independently require Owner authority;
- only unused-index INFO remains for newly created actor indexes with no production traffic;
- no new unindexed foreign-key finding.

## Canonical verification

Pre-hosted technical gate:

- JS: 14 files, 73/73 tests PASS
- Python: 132/132 tests PASS
- format: PASS
- lint: PASS
- typecheck: PASS
- build: PASS
- git diff --check: PASS

## Roadmap accounting

FIN-P4 is still a partial Finance milestone checkpoint.

Whole-project earned progress remains 78.0%. The 10% Finance bucket is earned only after final finance acceptance closes.

## Next action

Run a bounded Finance closure audit to inventory remaining **locked** scope against Blueprint authority.

Do not invent:

- employee Kasbon repayment/deduction rules;
- month-close/reopen rules;
- provider auto-verification;
- debt due-date/aging/interest policy.

Only remaining finance features with already-locked authority may proceed automatically.
