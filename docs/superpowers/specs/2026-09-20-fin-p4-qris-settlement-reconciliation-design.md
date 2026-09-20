# FIN-P4 QRIS Settlement & Daily Finance Reconciliation Design

**Date:** 2026-09-20  
**Status:** LOCKED FOR IMPLEMENTATION  
**Baseline:** FIN-P3 LOCKED_REMOTE at a9da1329a38e6d3f1bebc914b5fea56d0b073d10

## Authority

Blueprint rules:

- Keuangan is the single money authority.
- QRIS received is not cash.
- QRIS sale money first belongs to QRIS Belum Cair.
- Settlement flows QRIS Belum Cair -> QRIS Sudah Cair -> Bank.
- MDR/provider fee is a finance expense, not a reduction of sale revenue.
- Internal account transfers are not new income.
- Daily reconciliation minimally checks:
  - expected cash vs counted cash;
  - QRIS recorded vs settlement;
  - transfer recorded vs received;
  - stock system vs physical/check result when available.
- Daily result is SESUAI or PERLU_DIPERIKSA.
- Global finance and reconciliation are Owner-only.

## Scope

FIN-P4 provides two backend authorities:

1. QRIS settlement fact and command.
2. Daily finance reconciliation snapshot and command.

No automated provider API, no QRIS auto-verification, no month close/reopen, and no report UI is introduced.

## QRIS settlement fact

`qris_settlements` is immutable and stores:

- business;
- settlement date;
- external/provider reference;
- gross amount;
- provider fee;
- net amount;
- actor;
- gross settlement movement;
- fee movement nullable when fee is zero;
- bank-transfer movement;
- created timestamp.

Posting:

1. ensure Owner and sufficient QRIS_BELUM_CAIR balance;
2. SETTLEMENT gross from QRIS_BELUM_CAIR -> QRIS_SUDAH_CAIR;
3. if provider_fee > 0, EXPENSE provider fee from QRIS_SUDAH_CAIR;
4. TRANSFER net from QRIS_SUDAH_CAIR -> BANK;
5. write one immutable settlement fact and audit event.

Revenue is never rewritten.

## Daily reconciliation snapshot

`finance_daily_reconciliations` is immutable.

Inputs:

- business_date;
- counted_cash;
- bank_transfer_received;
- optional stock status: SESUAI / PERLU_DIPERIKSA / NOT_CHECKED;
- idempotency key.

System-derived as-of the end of business date:

- expected cash = KAS_UTAMA + KAS_SHIFT ledger balances;
- QRIS recorded = QRIS sale income posted that date;
- QRIS settled = gross QRIS settlements for that date;
- transfer recorded = transfer-method sale income posted to BANK that date.

Variances:

- cash_variance = counted_cash - expected_cash;
- qris_variance = qris_settled - qris_recorded;
- transfer_variance = bank_transfer_received - transfer_recorded.

Overall result is SESUAI only when all numeric variances are zero and stock status is not PERLU_DIPERIKSA. Otherwise PERLU_DIPERIKSA.

The snapshot stores the observed numbers at reconciliation time so later transactions do not rewrite the historical reconciliation fact.

## Security

All FIN-P4 commands and fact reads are Owner-only.

Public SECURITY DEFINER commands:

- pin search_path;
- obtain current authority;
- require owner=true;
- never accept business_id/actor_id from browser input.

Direct inserts/updates/deletes are revoked.

## Explicit non-goals

- automatic QRIS provider integration;
- matching individual QRIS provider transaction IDs to individual sales;
- split payment;
- month close/reopen;
- employee Kasbon;
- HPP/profit reporting;
- reconciliation UI/Excel.
