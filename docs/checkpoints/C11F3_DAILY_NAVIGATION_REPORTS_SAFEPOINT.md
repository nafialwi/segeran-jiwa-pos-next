# C11-F3 — Daily Navigation & Reports Safe Point

Date: 2026-09-23

## Purpose

C11-F3 aligns the primary navigation with daily work and makes Reports faster to
use without weakening the existing report authority model.

This batch implements the product decision that the bottom-navigation
"Perhatian" slot should become "Laporan", while preserving Perhatian as a
secondary operational surface under Menu.

Baseline:

- branch: work/c11-visual-convergence
- baseline commit: 85926061cf38c37e7de37c15d5a93ae3d8afa3d4
- database/schema: unchanged
- Production: untouched

## What changed

### 1. Primary navigation

The canonical primary-navigation family is now:

- Beranda
- Jual (when authorized)
- Riwayat (when authorized)
- Laporan (when authorized)
- Menu

The old primary "Perhatian" entry is removed from the bottom/sidebar primary
family.

### 2. Perhatian remains available

Perhatian was not deleted.

It now appears as a normal Operasional card inside Menu:

- label: Perhatian
- destination: /perhatian
- purpose: connectivity/status/evidence items that need review

When /perhatian is open, Menu is the active primary-navigation family. This
reflects its new role as a secondary operational/control surface rather than a
daily primary destination.

### 3. Laporan remains permission-safe

The Laporan primary item is only emitted when the current authority already has
at least one existing report permission:

- REPORT_SALES_LIMITED
- REPORT_INVENTORY
- REPORT_PURCHASE

No new report permission was granted in C11-F3.

This is deliberate. The current REPORT_SALES_LIMITED backend projection is
business-wide for SALES/PRODUCT data, not automatically cashier-own-only.
Therefore C11-F3 does not silently grant that permission to the default KASIR
role merely to fill a navigation slot.

Owner continues to see Laporan because Owner authority satisfies the report
permission boundary. Restricted users do not get an Access Denied trap in their
primary navigation.

### 4. Reports now start from daily-use context

Reports previously defaulted to the start of the current month.

C11-F3 changes the initial report range to Hari ini because the route is now a
daily primary destination.

Quick period controls are added:

- Hari ini
- 7 hari
- Bulan ini
- Custom

The controls are touch-safe, horizontally resilient on narrow phones, and expose
aria-pressed state.

Changing a quick period updates the visible date range immediately and clears any
old report result so stale data cannot appear under a new filter.

Editing either date manually switches the period to Custom and also clears the
old result.

### 5. Existing C11-F1 result visibility is preserved

Tampilkan Laporan still loads through the existing report authority. When the
new report arrives, the result is automatically brought into view using the
C11-F1 result-reveal behavior.

Excel export behavior is unchanged.

## What did NOT change

C11-F3 does not change:

- report RPC/query semantics;
- who is allowed to read a report;
- REPORT_SALES_LIMITED scope;
- Owner authority;
- default KASIR role permissions;
- transaction, Shift, Inventory, Finance, Purchase, Product, or ledger authority;
- database schema/migrations;
- Production deployment.

No report data is copied into a new reporting ledger.

## Verification

Focused regression:

- C11-F3 Python tests: 6/6 PASS
- C1 navigation tests: 5/5 PASS

Canonical repository verification:

- repo guard: PASS
- Prettier: PASS
- ESLint: PASS
- TypeScript: PASS
- JavaScript: 96/96 PASS
- Python: 394/394 PASS
- production build: PASS
- git diff --check: PASS

The existing Vite ineffective-dynamic-import advisory for src/lib/supabase.ts
remains unchanged and was not introduced by C11-F3.

## Safety conclusion

C11-F3 is a safe daily-navigation/report-ergonomics checkpoint.

It delivers the requested Perhatian -> Laporan primary-navigation change for
authorized report users, keeps Perhatian reachable in Menu, makes daily report
period selection faster, and does not broaden sensitive report visibility.

## Remaining fit-and-proper work

Still pending after C11-F3:

- Product Media: upload/preview/replace/remove/compress product image and render it
  in Jual with safe placeholder behavior;
- decide/design a cashier-own daily report surface if default KASIR should receive
  a report shortcut without business-wide REPORT_SALES_LIMITED exposure;
- replace remaining browser-native prompt/confirm flows where an internal focused
  dialog is safer and more consistent;
- numeric/decimal keyboard and input-mode sweep;
- remaining screen-by-screen focus/context polish;
- 320/360/390/412 + desktop visual matrix;
- Owner/Kasir real-device UAT;
- final full regression and C11 Fit & Proper lock.
