# C11-D — Inventory, Recipe, Purchase, Production & Shift Safe Point

Date: 2026-09-23

## Scope

C11-D converges Refinement 03 and reduces perceived loading delay on operational screens without weakening any RC4 authority boundary.

Covered surfaces:

- Sales first-paint loading path;
- Inventory overview and item-detail navigation;
- Product / Variant / Recipe / Packaging;
- Purchase / Supplier / Goods Receipt;
- Production / Active BOM / Batch;
- Shift / Reconciliation / Packaging control / Closing.

## Loading-efficiency hardening

### Sales / Jual

Before C11-D, first paint waited for:

1. active shift;
2. sales catalog;
3. customer list;
4. manual QRIS image.

The catalog, customer list, and QRIS support data were awaited together.

C11-D changes the critical path to:

1. active shift;
2. sales catalog;
3. render POS immediately;
4. warm customer list and QRIS in the background.

Selecting Kasbon or QRIS also explicitly ensures its support data is loaded. Checkout authority is unchanged.

### Product & Recipe

The initial Product screen no longer waits for the separate BOM component picker query.
Product/Variant data renders first. BOM picker options are loaded only when the Recipe tab is opened by a user with production-management authority.

### Purchase

Purchase front-door options and finance/payable summary now resolve independently.
The operational workflow can become usable as soon as front-door options arrive instead of waiting for the finance summary.

### Shift

The active-shift query can complete and render the shift workspace while locations continue loading independently.
Locations remain required before opening a new shift.

### Inventory detail

Inventory item detail uses request-in-flight de-duplication only, with no retained stale cache.
Pointer-down prefetch starts the detail request just before navigation; the detail screen reuses the same in-flight request if it is still running.

### Production

Production now exposes honest skeleton/loading states while its authoritative overview resolves instead of briefly presenting an empty-state as if no BOM or batches existed.

## Refinement 03 visual convergence

- operational headers use the Segeran Jiwa cream/green visual language;
- Inventory summary and item cards have clearer hierarchy;
- stock-item kind is surfaced as a compact chip without inventing stock-health thresholds;
- Detail Barang has a stronger product/packaging identity surface;
- Product & Recipe has a searchable sticky product list, stronger selected-product hero, and refined tabs;
- Purchase front doors are icon-led and grouped into Direct Buy, Supplier Order, Goods Receipt, and Master Data;
- Production exposes the selected finished good and active BOM before batch creation;
- Shift KPIs and actions are icon-led, with packaging control remaining part of the canonical inventory engine;
- phone layouts remain mobile-first at <=520 px and <=360 px, with desktop adaptations at >=960 px.

## Truthfulness boundaries

C11-D intentionally does not invent:

- product photography that is not present in authoritative data;
- stock health labels such as Aman/Menipis without a configured threshold authority;
- a second cup/packaging inventory engine;
- synthetic realtime backup/health facts.

## Authority preserved

No database migration, RPC definition, table schema, permission, transaction writer, inventory writer, finance writer, production writer, shift writer, offline mutation behavior, or refund/correction authority was changed.

Packaging remains:

- Stock Item with item_kind = PACKAGING;
- variant usage through variant_sale_components;
- immutable sale-time usage snapshots;
- shift theoretical usage through shift_packaging_usage(uuid);
- physical count through Inventory Stock Count.

## Verification

Focused C11-D, C5-A/C5-B, Sales, POS mobile, and shift tests: PASS.

Full canonical verification:

- JavaScript: **96/96 PASS**;
- Python: **320/320 PASS**;
- repository guard: PASS;
- Prettier: PASS;
- ESLint: PASS;
- TypeScript: PASS;
- production build: PASS;
- git diff-check: PASS.

## Release status

C11-D is a development safe point only.

RC4 remains immutable as the last accepted UAT release candidate.
Production automatic deployment remains disabled.
RC5 must not be created until C11-E and C11-F are complete.
