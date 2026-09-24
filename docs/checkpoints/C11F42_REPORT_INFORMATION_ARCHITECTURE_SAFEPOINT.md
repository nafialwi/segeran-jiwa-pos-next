# C11-F4.2 — Report Information Architecture & Semantic Density Safe Point

Date: 2026-09-24

## Purpose

C11-F4.2 corrects the information hierarchy found during real-device review after
C11-F4.1. The compact-list interaction was already scalable, but several rows were
still technically correct while operationally ambiguous.

Examples observed on device:

- Finance money rows could appear only as `INCOME — Rp ...`;
- customer debt rows could appear primarily as `OPEN — Rp ...`;
- repeated normal statuses could dominate rows without helping identify the fact.

The goal is that every compact row explains what the fact is before Detail opens.

Baseline:

- branch: `work/c11-visual-convergence`
- baseline commit: `245e06f97cf40d43677838afda3f58badfbef33f`
- previous tag: `c11-f4.1-compact-report-drilldown-safepoint`
- report authority, schema, and Production are unchanged.

## Information architecture rule

All reports continue to use one universal interaction:

`overview -> semantic compact list -> detail on demand`

The component remains universal. Semantic identity is selected by
`report_code + section.key`, so each business fact can prioritize the right
fields without creating separate UI systems.

A compact row is limited to:

1. one primary identity;
2. up to two supporting context lines;
3. one primary metric;
4. status only when it adds operational value.

Every original report column remains available in the detail sheet.

## Semantic identity implemented

Sales transactions use event + payment method as readable identity, with
transaction reference and date/user as context and nominal as primary metric.
Normal `COMPLETED` is quiet.

Product rows use product name as primary identity, variant/category and clean
quantity as context, and net item value as metric.
Inventory balance rows use product, location, item kind/unit, and quantity.
Inventory movement rows use product, date/location, movement reason, and signed
quantity delta.

Shift rows use cashier as primary identity, opened time/location as context, and
expected cash as the main compact metric. Closed status is quiet.

Purchase order rows use supplier, order number, date/location, and total.
Goods-receipt rows use supplier, receipt number, date/location, and received base
quantity. Supplier-payable rows use supplier identity and outstanding balance.

Finance account rows use account name, code/type, and balance.

Finance money-flow rows prefer `source` as identity, then reason, then movement
kind. Reference/account flow and timestamp/movement kind become context. This
prevents unrelated rows from all presenting only as `INCOME`.

Business expenses use description/category and amount. Customer debt uses
customer identity and outstanding balance. Supplier payable uses supplier
identity and outstanding balance. Employee kasbon uses employee identity and
outstanding balance.

The customer-debt section is presented as **Piutang Pelanggan** because it
represents money owed to the business. Backend keys and data contract are unchanged.

## Status policy

Status is anomaly-first:

- normal completion states such as `COMPLETED`, `CLOSED`, `POSTED`,
  `PAID`, and `RECEIVED` do not repeat on every row;
- non-normal or action-relevant states can surface as a compact status chip;
- open debt/payable/kasbon state remains visible because it is part of the meaning
  of the outstanding balance.

This is presentation logic only.

## Density and mobile ergonomics

C11-F4.2 further reduces non-essential vertical space:

- compact rows use a 52px minimum height;
- section counts use a content-width chip instead of stretching across the card;
- report headings remain horizontal on phone;
- empty states use concise operational messages;
- the visible search label is collapsed on phone but remains accessible;
- filter/sort chips remain horizontally scrollable and touch-safe.

Pagination from C11-F4.1 remains 20 rows per page.

## Truth and authority boundaries

C11-F4.2 does not change:

- `report_run` RPC semantics or query scope;
- report permissions or default KASIR authority;
- Owner-only report boundaries;
- report summary/totals truth;
- Excel export source;
- transaction, inventory, finance, shift, purchase, or product writers;
- database tables or migrations;
- Production deployment.

Search, filter, sort, pagination, semantic row selection, and detail rendering
operate only on the already-authorized report envelope.

## Verification

Focused regression:

- C11-F4 + F4.1 + F4.2 report tests: **18/18 PASS**
- C11-F4.2 focused tests: **6/6 PASS**

Canonical verification after implementation:

- JavaScript: **96/96 PASS**
- Python: **412/412 PASS**
- repo guard, Prettier, ESLint, TypeScript, production build, and diff-check: **PASS**
  The pre-existing Vite `INEFFECTIVE_DYNAMIC_IMPORT` advisory for
  `src/lib/supabase.ts` remains unchanged and is not introduced by this batch.

## Safety conclusion

C11-F4.2 is a presentation-layer safe point. Compact rows are now both scalable
and semantically useful before drill-down, while the complete authoritative row
remains available in Detail.

## Remaining C11 work

Next planned stage after real-device acceptance:

1. C11-F5 — Product Media & catalog completion;
2. C11-F6 — interaction cleanup and input-mode sweep;
3. C11-F7 — full responsive matrix;
4. C11-F8 — Owner/Kasir real-device UAT;
5. C11-F9 — final regression;
6. C11 Final Lock / RC5 after blockers are zero.
