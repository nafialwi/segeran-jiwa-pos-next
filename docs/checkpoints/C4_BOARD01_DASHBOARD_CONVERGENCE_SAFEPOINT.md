# C4 Board 01 Role-Aware Dashboard Convergence — SAFEPOINT

Date: 2026-09-22

Branch: `work/cs06743-patch3-hardening`

## Outcome

C4 replaces the old engineering/navigation-grid Home surface with the approved Board 01 role-aware dashboard presentation.

UI and UX convergence is performed together with functional convergence. C4 is therefore not only CSS polish: the information hierarchy, role-specific content, loading/error behavior, responsive layout, quick actions, and deep links are aligned to existing business authorities.

No new business writer, database ledger, or duplicate dashboard data source was created.

## Baseline preserved

C4 started from:

- C3-B safe commit: `f0709eae2f29e3d4c4e840026ff063b929509095`
- branch: `work/cs06743-patch3-hardening`
- immutable RC1: `uat-rc-20260921-1 -> e844f9b9ad07ca240e1ba4f72a39c6c7aefbb489`
- RC1 Preview: `https://5188a6b0.segeran-jiwa-pos-next.pages.dev`
- Production automatic deployment: **DISABLED**

C2/C3 migrations remain source-controlled and are not persistently applied to the hosted operational database.

## Home information architecture

The previous Home page was primarily a permission-aware list of navigation cards.

C4 changes the Home authority to:

```text
Authenticated user
  -> role-aware Home
       -> Owner Dashboard
       OR
       -> Cashier Dashboard
```

Full module navigation remains available through the canonical Menu surface established in C1.

This is intentional information-architecture convergence, not route removal.

## Owner Dashboard

The Owner dashboard now shows evidence-backed business information:

- **Penjualan Hari Ini**
- **Transaksi**
- **Kas Tersedia**
- **QRIS Belum Cair**
- **Tren 7 Hari**
- **Produk Terlaris**
- role-appropriate quick actions
- **Perlu Perhatian**

### Owner sales authority

Sales KPIs, trend, and best-seller data reuse the canonical `report_run` / `runReport('SALES', ...)` read authority.

No second sales aggregation writer is created.

`Penjualan Hari Ini` uses the report's net-sales authority after refund/correction treatment.

The seven-day trend is derived from the canonical SALES transaction rows, preserving the report's signed sale/refund/correction interpretation.

Best sellers use the Product/Variant product report rows created by the C2-C read projection, not consumed inventory components.

### Owner finance authority

Global finance KPIs read the existing owner-bounded money authorities:

- `KAS_UTAMA`
- `KAS_SHIFT`
- `QRIS_BELUM_CAIR`
- `money_balances`

Dashboard interpretation:

```text
Kas Tersedia
  = KAS_UTAMA + KAS_SHIFT

QRIS Belum Cair
  = QRIS_BELUM_CAIR
```

The finance tables already use Owner-only RLS after finance hardening.

C4 performs no finance mutation.

## Cashier Dashboard

The Cashier dashboard intentionally does **not** fetch global finance balances or the Owner sales report.

It reads only existing shift authorities:

- `fetchMyOpenShift()`
- `fetchShiftReconciliation(shift.id)`

When a shift is active it shows:

- **Shift Aktif**
- opening cash
- **Penjualan Shift**
- **Kas Diharapkan**
- refund context when present
- **Jual Sekarang**
- permission-aware quick actions.

When no shift is open it shows a truthful **Shift Belum Aktif** state and a permission-aware **Buka Shift** action.

This preserves the blueprint rule that Cashier must not see Owner-global finance/profit data without explicit authority.

## Owner Message

Board 01 includes an Owner-message surface, but no canonical Owner-message backend authority exists yet.

C4 therefore uses a truthful empty/deferred state:

> Belum ada kanal pesan operasional yang aktif.

No fake message, fake timestamp, or invented Owner instruction is shown.

## Attention

The Home dashboard deep-links to the canonical `/perhatian` authority.

Current attention text remains evidence-bounded to what the application can truthfully know.

In particular:

- offline browser state may surface attention;
- online browser state does **not** claim backend health is good;
- no fake backend-health counter is shown.

This preserves the P5A hardening boundary.

## UI / UX convergence

C4 uses the C1 design-system authority:

- warm cream application background;
- deep Segeran Jiwa green;
- white operational cards;
- subtle borders/shadows;
- C1 icon registry;
- compact KPI hierarchy;
- responsive card layout;
- mobile-first behavior;
- wider desktop content alongside the existing sidebar.

Responsive behavior includes:

- mobile two-column KPI grid;
- stacked hero/shift surfaces on narrow screens;
- desktop four-column Owner KPI grid;
- desktop split layout for seven-day trend and best sellers;
- four-column quick actions at wider widths.

No full-screen dashboard spinner is introduced.

Loading uses card-level skeletons. Errors replace the skeleton with a localized dashboard error card rather than blocking the entire application shell.

## Navigation regression alignment

Two historical tests still assumed operational links had to remain physically present on Home:

- Inventory / Purchase / Legacy Import
- Expense Approval

C1 had already established `Menu` as the canonical full-module navigation surface, and C4 intentionally makes Home a dashboard.

Those tests were updated to prove:

- the routes still exist in `App.tsx`;
- the operational links still exist in `MenuScreen`;
- the screens themselves still exist.

No operational route was removed.

## Source changes

New read composition:

`src/dashboard/dashboard-api.ts`

Reworked role-aware dashboard:

`src/screens/HomeScreen.tsx`

Responsive C4 styling:

`src/app.css`

New C4 contract test:

`tests/test_c4_dashboard_convergence.py`

Historical IA regression tests updated to the canonical Menu authority:

- `tests/test_uat_blocker_core_recovery.py`
- `tests/test_fin_p6_expense_approval.py`

## Tests and verification

C4 focused contract:

- **7/7 PASS**

C4 + related route/report/finance/history targeted regression:

- **27/27 PASS**

After IA test alignment:

- relevant C4/UAT/finance approval subset: PASS

Canonical verification before this checkpoint document:

- repository guard: PASS
- formatting: PASS
- lint: PASS
- TypeScript typecheck: PASS
- JavaScript: **96/96 PASS**
- Python: **248/248 PASS**
- production build: PASS
- `git diff --check`: PASS

A final canonical verification is required again after this checkpoint document before commit/push.

## Persistent database / deployment impact

**NONE.**

C4 is a read-model + UI/UX convergence checkpoint.

- no new database migration;
- no persistent hosted schema mutation;
- no persistent hosted business-data mutation;
- no new sales writer;
- no new inventory writer;
- no new finance writer;
- no new shift writer;
- RC1 remains immutable;
- RC1 Preview remains unchanged;
- Production remains unchanged;
- automatic Production deployment remains disabled.

## What is now converged

```text
C1
AppShell / navigation / icons
  +
C2
Product / Variant / V2 execution / readers
  +
C3
Board 02 Sales / checkout / history facts
  +
C4
Board 01 Owner / Cashier dashboards
```

The primary application shell, sale flow, and Home dashboard now share the same visual and authority model in source.

## Next safe phase

**C5 — Board 03 Operations Convergence.**

Converge the existing operational modules onto the approved Board 03 UX without replacing their canonical engines:

- Persediaan;
- Detail Barang;
- Produk / Varian / Resep / Kemasan;
- Pembelian;
- Produksi;
- Shift / packaging control.

C5 should preserve the one-inventory-engine and one-production-recipe-authority rules.

Persistent database promotion and a new Cloudflare Preview remain gated for the later RC2 promotion phase.
