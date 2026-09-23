# C11-F4.1 — Compact Report List & Drill-down Safe Point

Date: 2026-09-24

## Purpose

C11-F4.1 refines the C11-F4 mobile report presentation after real-use feedback
showed that readable cards were still too tall for large result sets.

The goal is to keep all report facts available while making 100+ row reports
practical to scan on a phone.

Baseline:

- branch: `work/c11-visual-convergence`
- baseline commit: `9dda046cd34f966569398a456a4b383967e71e15`
- database/schema: unchanged
- report RPC/query authority: unchanged
- Production: untouched

## What changed

### 1. One universal compact-list pattern

All report families now share one ReportSectionView / ReportCompactRow pattern.
The visual structure is no longer split into a large Product card concept and a
large Sales card concept. The component is universal; only the small set of fields
used to identify a row is selected from the existing report columns.

On phone widths each row is a compact tappable line with:

- the row's primary identity;
- up to two supporting facts;
- one main numeric/money metric when present;
- a drill-down affordance.

Technical fields such as long product codes remain searchable and available in
detail without forcing every compact row to become tall.

### 2. Detail on demand

Tapping any compact report row opens an internal detail sheet containing every
column already present in that authoritative report row.

The same detail surface is available from desktop table rows.

The detail surface:

- does not fetch broader data;
- does not invent transaction-to-product drill-down relationships;
- does not add a new route or ledger;
- locks background scrolling while open;
- closes by explicit close action, backdrop click, or Escape.

### 3. Client-side pagination

Each report section renders 20 rows per page.
Pagination is applied to both the compact phone list and the desktop table so a
large report does not create an excessively long page.

The UI shows the visible range, for example `1–20 dari 100`, with Previous and
Next controls.

Search/filter/sort changes reset pagination to page 1 and close any stale open
detail. Pagination operates only on rows already returned by the authorized
report envelope.

### 4. Summary density

Phone KPI cards were tightened without lowering the C11 readability floor:

- smaller internal padding;
- smaller grid gaps;
- compact caption sizing;
- odd final KPI full-row behavior from C11-F4 remains intact.

This reduces the distance between the report header and its operational rows.

## Authority and truth boundaries preserved

C11-F4.1 does not change:

- `report_run` RPC semantics;
- report permission scope;
- default KASIR authority;
- Owner-only report boundaries;
- report summaries or totals;
- Excel export content;
- transaction, inventory, finance, shift, purchase, or product writers;
- database schema/migrations;
- Production deployment.
  Search, filter, sort, pagination, and drill-down are presentation-only operations
  over the already-authorized report envelope.

## Verification

Focused C11-F4.1 regression:

- C11-F4.1 Python tests: **6/6 PASS**
- TypeScript: **PASS**
- ESLint: **PASS**
- Prettier: **PASS**

Canonical repository verification after implementation:

- repo guard: **PASS**
- Prettier: **PASS**
- ESLint: **PASS**
- TypeScript: **PASS**
- JavaScript: **96/96 PASS**
- Python: **406/406 PASS**
- production build: **PASS**
- `git diff --check`: **PASS**

The existing Vite ineffective-dynamic-import advisory for `src/lib/supabase.ts`
remains unchanged.

## Safety conclusion

C11-F4.1 is a safe report-density checkpoint. Large report result sets are now
scannable without removing detail, and every report family follows the same
compact-list → detail-on-demand interaction model.

## Remaining C11 fit-and-proper work

Next planned stage:

1. C11-F5 — Product Media & catalog completion;
2. C11-F6 — interaction cleanup and input-mode sweep;
3. C11-F7 — full responsive matrix;
4. C11-F8 — Owner/Kasir real-device UAT;
5. C11-F9 — final regression;
6. C11 Final Lock / RC5 only after blockers are zero.
