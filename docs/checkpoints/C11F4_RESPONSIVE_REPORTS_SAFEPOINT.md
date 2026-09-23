# C11-F4 — Responsive Reports & Mobile Readability Safe Point

Date: 2026-09-24

## Purpose

C11-F4 closes the mobile readability defect observed on real-device screenshots of
Laporan Produk and Laporan Penjualan, where wide report tables were compressed into
narrow phone columns and labels, codes, dates, values, and statuses broke into
near-vertical text.

Baseline:

- branch: `work/c11-visual-convergence`
- baseline commit: `da80a2f2b1de25fc337c87e52b78e733e165e936`
- database/schema: unchanged
- report RPC/query authority: unchanged
- Production: untouched

## What changed

### 1. Responsive report rendering

Report rows now have two presentation modes over the same authoritative report
envelope:

- phone widths: readable report cards;
- tablet/desktop widths: structured tables.

Mobile cards prioritize human-operational identity before technical metadata. Product
reports prioritize Product / Category / Code; Sales prioritizes Transaction Number /
Status / Date. Other report families use a bounded generic fallback rather than
forcing every column into a phone-width table.

Desktop tables remain available and now preserve minimum table geometry so columns
do not collapse into one-character or one-word vertical fragments.

### 2. Display-only search, filter, and sort

Loaded report results can now be searched client-side. Product reports expose
category filtering and Qty/Value ordering; Sales exposes payment-method filtering
and Value ordering when the corresponding report columns are present.

These controls are presentation-only:

- they do not call a new backend;
- they do not change report permissions;
- they do not alter the report summary;
- they do not alter Excel export content;
- they do not write business data.

The UI explicitly states that filtered/sorted display does not redefine the report
facts.

### 3. Date readability

Report date values and the report period heading now use Indonesian human-readable
date formatting instead of exposing raw ISO dates where a date format is declared.

The seven-day preset remains inclusive seven days (`today - 6 days` through today);
C11-F4 does not change its date-range semantics.

### 4. Mobile geometry and bottom-navigation clearance

At phone widths:

- summary KPIs use a stable two-column grid;
- an odd final KPI spans the full row instead of leaving an accidental half-row gap;
- report rows use two-column detail grids inside cards;
- filter/sort controls remain horizontally scrollable and touch-safe;
- the desktop table renderer is hidden;
- report content reserves bottom safe-area/navigation clearance.

This prevents the real-device failure mode captured before C11-F4 without shrinking
important text below the C11 readability floor.

## Authority and data boundaries preserved

C11-F4 does not change:

- `report_run` RPC semantics;
- `REPORT_SALES_LIMITED`, `REPORT_INVENTORY`, or `REPORT_PURCHASE` scope;
- Owner-only Shift/Finance report authority;
- default KASIR permissions;
- report source-of-truth or ledger semantics;
- Excel export authority/content;
- transaction, inventory, finance, shift, product, or purchase writers;
- database schema/migrations;
- Production deployment.

## Verification

Focused C11-F4 regression:

- C11-F4 Python tests: **6/6 PASS**
- TypeScript focused check: **PASS**
- ESLint: **PASS**
- Prettier: **PASS**

Canonical repository verification after implementation:

- repo guard: **PASS**
- Prettier: **PASS**
- ESLint: **PASS**
- TypeScript: **PASS**
- JavaScript: **96/96 PASS**
- Python: **400/400 PASS**
- production build: **PASS**
- `git diff --check`: **PASS**

The existing Vite ineffective-dynamic-import advisory for `src/lib/supabase.ts`
remains unchanged and was not introduced by C11-F4.

## Safety conclusion

C11-F4 is a safe responsive-report presentation checkpoint. The real-device report
readability defect is closed at source level while report data authority and export
truth remain unchanged.

## Remaining C11 fit-and-proper work

After this safe point, the planned order is:

1. C11-F5 — Product Media & catalog completion;
2. C11-F6 — daily interaction cleanup, remaining native prompt/confirm replacement,
   and numeric/input-mode sweep;
3. C11-F7 — complete 320/360/390/412 px + tablet/desktop visual matrix;
4. C11-F8 — Owner/Kasir real-device end-to-end UAT;
5. C11-F9 — final regression/hardening;
6. C11 Final Lock / RC5 only after all blockers are zero.

A cashier-own report capability remains a separate permission/data-projection design
question and is intentionally not smuggled into this presentation batch.
