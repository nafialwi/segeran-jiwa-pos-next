# C5-A Board 03 Operations Front Door — SAFEPOINT

Date: 2026-09-22

Branch: `work/cs06743-patch3-hardening`

## Outcome

C5-A establishes the first coherent Board 03 operational workspace without replacing any
inventory, purchase, production, or shift business authority.

The operations area now has one shared navigation and first-class front doors for:

- Persediaan;
- Detail Barang;
- Produk & Resep;
- Pembelian;
- Produksi;
- Shift.

The design is mobile-first and uses the C1 design system, while desktop/tablet receive responsive
multi-column layouts.

This checkpoint is source-only. It does not apply the post-RC1 C2/C3 migrations persistently and
does not create a new Cloudflare Preview.

## Baseline preserved

C5-A started from the C4 safe point:

- commit:
  `58d2c4183f33370bdd24292ce79f1f9a91344a3d`
- branch:
  `work/cs06743-patch3-hardening`
- immutable RC1:
  `uat-rc-20260921-1 -> e844f9b9ad07ca240e1ba4f72a39c6c7aefbb489`
- RC1 Preview:
  `https://5188a6b0.segeran-jiwa-pos-next.pages.dev`
- Production automatic deployment:
  **DISABLED**

## Narrow C5 contract review

The C5 work did not restart architecture discovery.

The existing operational authorities were inspected only as needed to identify the correct
front-door contracts.

Verified existing authorities:

### Inventory

- `inventory_operational_overview()` is the permission/location-bounded inventory read authority.
- `inventory_movements` and `inventory_movement_lines` remain immutable stock facts.
- `inventory_balances` remains derived from movement lines.
- inventory counts/adjustments/restock/transfer already have their own existing backend authorities.

### Purchase

The existing Purchase front door already uses the canonical purchase RPCs:

- supplier creation;
- item creation;
- purchase order;
- direct purchase;
- goods receipt;
- goods receipt posting.

Creating a PO or draft receipt does not independently invent stock.
Actual stock posting remains through the established goods-receipt authority.

### BOM / Recipe

Existing production recipe authority remains:

- `boms`;
- `bom_lines`;
- `save_bom_draft`;
- `activate_bom`.

This is intentionally distinct from C2 sale-stage Product/Variant component configuration.

### Production

Existing production writers remain:

- `create_production_batch`;
- `post_production_batch`.

Production posting still creates one canonical inventory movement that:

- consumes BOM components;
- adds actual finished-good output.

C5-A introduces no second production or inventory writer.

### Shift

Existing Shift authority remains unchanged.
C5-A only gives Shift the same operations-navigation context.

## Shared Board 03 navigation

New component:

`src/components/OperationsNav.tsx`

The shared operational navigation exposes modules only when the active authority is allowed to see
them:

- Persediaan -> `/stok`
- Produk & Resep -> `/produk`
- Pembelian -> `/pembelian`
- Produksi -> `/produksi`
- Shift -> `/shift`

The same permission rules are aligned in `canAccessRoute(...)`.

No hidden navigation shortcut bypasses route authority.

## Persediaan convergence

`InventoryScreen` is no longer an administrative horizontal table as its primary mobile
presentation.

It now provides:

- inventory summary cards;
- search;
- location filter;
- explicit item-kind filter;
- grouped item cards;
- tracked-stock vs non-stock language;
- sale status/price context;
- direct navigation to Detail Barang.

No arbitrary low-stock threshold was invented.

The screen does not claim an item is low merely because its quantity looks small.

## Detail Barang

New route:

`/stok/:stockItemId`

New screen:

`src/screens/InventoryItemScreen.tsx`

It shows:

- item identity;
- tracked/non-stock state;
- saldo per location;
- recent inventory movements;
- signed quantity delta;
- movement reason;
- source type/reference;
- timestamp.

Read implementation:

`src/inventory/inventory-api.ts`

It reads the existing:

- `inventory_operational_overview`;
- `inventory_movement_lines`;
- `inventory_movements`;
- `locations`.

There is no direct insert/update/delete in this C5-A inventory read client.

## Produk & Resep front door

New route:

`/produk`

New read-only front door:

`src/screens/ProductOperationsScreen.tsx`

Read client:

`src/operations/product-api.ts`

The presentation keeps distinct concepts separate:

```
Sale Product
  -> Variant
     -> SALE-stage Ingredient / Packaging
     -> DIRECT_STOCK / MAKE_TO_ORDER / PREPRODUCED

PREPRODUCED finished good
  -> versioned BOM
     -> Production
```

Tabs:

- Informasi;
- Varian;
- Resep;
- Kemasan.

The screen visibly distinguishes:

- MAKE_TO_ORDER;
- PREPRODUCED;
- direct stock;
- sale-stage ingredients;
- sale-stage packaging;
- BOM Produksi.

It does not merge BOM production recipes into the C2 sale-stage component table.

### RC2 schema boundary

The Product/Variant front door depends on the C2 tables:

- `sale_products`;
- `product_variants`;
- `variant_sale_components`.

Because C2 remains unapplied persistently on the current hosted RC1 environment, a missing C2
relation fails closed as:

`REFINEMENT_DATABASE_NOT_READY`

No Legacy Product/Variant approximation is silently fabricated.

C5-A intentionally keeps this product-configuration surface read-only.
A new write authority for sale-stage Product/Variant components is not invented here.

## Produksi front door

New route:

`/produksi`

New screen:

`src/screens/ProductionScreen.tsx`

New API facade:

`src/production/production-api.ts`

The screen exposes:

### Rencana Produksi

- production location;
- finished good;
- active BOM version;
- target output;
- create production batch.

Only finished goods with an ACTIVE BOM are offered.

### Batch Produksi

Draft batches show:

- finished good;
- location;
- BOM version;
- planned output;
- actual output input;
- Posting Produksi.

Posted batches show their actual output/post time.

The frontend calls only:

- `create_production_batch`;
- `post_production_batch`.

Online mutation boundaries remain enforced through `requireOnlineAction`.

The frontend does **not** call `record_inventory_movement` directly.

## Pembelian and Shift

C5-A does not rewrite their already-functional engines.

Instead:

- Purchase receives the shared `OperationsNav` and common operations-shell presentation;
- Shift receives the shared `OperationsNav` and common operations-shell presentation.

Their deeper Board 03 visual restructuring is deferred to C5-B so this checkpoint remains a
coherent, testable slice rather than a broad risky rewrite.

## Routes and permission alignment

New route coverage:

- `/stok/:stockItemId` -> `INVENTORY_READ`;
- `/produk` -> `INVENTORY_READ` or `PRODUCTION_MANAGE`;
- `/produksi` -> `PRODUCTION_MANAGE`.

Existing routes remain unchanged:

- `/stok`;
- `/pembelian`;
- `/shift`;
- `/handover`;
- `/rekonsiliasi`;
- and other operational routes.

Menu now exposes:

- Produk & Resep;
- Produksi;

only under the matching permission boundary.

## UI/UX convergence

C5-A continues the product rule that UI/UX and functional convergence proceed together.

New shared visual language includes:

- horizontal operational module navigation;
- summary cards;
- item cards;
- detail panels;
- Product/Variant tabs;
- component/BOM lists;
- production batch cards;
- responsive mobile/desktop layouts;
- card-level loading states.

The implementation uses existing C1 tokens such as:

- `--sj-brand-900`;
- `--sj-brand-soft`;
- `--sj-surface`;
- `--sj-surface-muted`;
- `--sj-border`;
- `--sj-text`;
- `--sj-text-muted`;
- `--sj-radius-md`.

## Source changes

New:

- `src/components/OperationsNav.tsx`
- `src/inventory/inventory-api.ts`
- `src/operations/product-api.ts`
- `src/production/production-api.ts`
- `src/screens/InventoryItemScreen.tsx`
- `src/screens/ProductOperationsScreen.tsx`
- `src/screens/ProductionScreen.tsx`
- `tests/test_c5a_operations_front_door.py`

Converged:

- `src/screens/InventoryScreen.tsx`
- `src/screens/PurchaseScreen.tsx`
- `src/screens/ShiftManagementScreen.tsx`
- `src/screens/MenuScreen.tsx`
- `src/App.tsx`
- `src/auth/permission.ts`
- `src/app.css`

## Tests and verification

C5-A focused source contract:

- **9/9 PASS**

Relevant existing C5 operational regression:

- Purchase front-door tests: PASS;
- BOM foundation tests: PASS;
- production-execution tests: PASS;
- inventory-control tests: PASS;
- Shift live-cash UI tests: PASS.

Combined relevant Python subset before full verification:

- **42/42 PASS** before the final route-permission hardening;
- C5-A focused suite remained **9/9 PASS** after route-permission hardening.

Full canonical verification before this checkpoint document:

- repository guard: PASS;
- formatting: PASS;
- lint: PASS;
- TypeScript typecheck: PASS;
- JavaScript: **96/96 PASS**;
- Python: **257/257 PASS**;
- production build: PASS;
- `git diff --check`: PASS.

A final canonical verification is required again after this document and project-state update before
commit/push.

## Persistent database / deployment impact

**NONE.**

C5-A adds no database migration.

- hosted schema unchanged;
- hosted business data unchanged;
- post-RC1 C2/C3 migrations remain unapplied persistently;
- RC1 remains immutable;
- RC1 Preview remains unchanged;
- no RC2 Preview created;
- Production remains unchanged;
- automatic Production deployment remains disabled.

## What is now converged

```
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
Board 01 Owner/Kasir dashboards
  +
C5-A
Board 03 operations navigation
Inventory front door + Detail Barang
Product/Variant/Recipe/Packaging read surface
Production front door
Purchase/Shift shared operational shell
```

## Intentionally deferred within Board 03

C5-A does not falsely claim that all Board 03 details are final.

Still deferred:

1. deeper Purchase UX grouping for:
   - Direct Buy;
   - Supplier Order;
   - Goods Receipt;
   - payable context;
2. deeper Shift UX convergence for:
   - opening;
   - active shift;
   - closing;
   - reconciliation;
   - packaging/cup evidence;
3. Owner configuration UI for production BOM draft/activate;
4. a separately designed, permission/idempotency-safe write authority for C2 sale-stage
   Product/Variant components if/when the final configuration UX requires it;
5. restock/transfer/count/adjustment operational controls as first-class Board 03 UI.

## Next safe phase

**C5-B — Board 03 Purchase / Shift / Recipe Configuration Convergence.**

Converge the remaining Board 03 operational surfaces using the existing authorities:

- restructure Purchase into clear Direct Buy / Supplier Order / Goods Receipt workflows;
- converge Shift opening / active / closing / reconciliation and packaging-control presentation;
- expose BOM draft/activate only through the existing versioned BOM authority;
- bring relevant restock/transfer/count/adjustment controls forward without bypassing their
  canonical inventory writers.

Do not persistently apply C2/C3 migrations or deploy a new Preview until the dedicated RC2
promotion gate.
