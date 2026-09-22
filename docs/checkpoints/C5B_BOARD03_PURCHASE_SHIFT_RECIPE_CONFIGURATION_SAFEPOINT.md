# C5-B Board 03 Purchase / Shift / Recipe Configuration — SAFEPOINT

Date: 2026-09-22

Branch: `work/cs06743-patch3-hardening`

## Outcome

C5-B completes the next coherent Board 03 operations slice on top of C5-A without introducing a
second inventory, purchase, production, shift, recipe, or packaging authority.

The operational workspace now converges:

- Purchase into distinct Direct Buy / Supplier Order / Goods Receipt workflows;
- Shift into Opening / Active / Reconciliation / Packaging Control / Closing presentation;
- versioned production BOM configuration through the existing BOM authority;
- inventory Restock / Transfer / Stock Count / Adjustment through existing canonical writers;
- packaging/cup physical control through inventory Stock Items, not a separate cup engine.

This is still source-only refinement. No post-RC1 C2/C3 migration is applied persistently and no
new Cloudflare Preview is created.

## Baseline preserved

C5-B started from the C5-A safe point:

- commit:
  `551d60131931d6f770df6bd64d9757e1ea54d4b8`
- branch:
  `work/cs06743-patch3-hardening`
- immutable RC1:
  `uat-rc-20260921-1 -> e844f9b9ad07ca240e1ba4f72a39c6c7aefbb489`
- RC1 Preview:
  `https://5188a6b0.segeran-jiwa-pos-next.pages.dev`
- Production automatic deployment:
  **DISABLED**

## Purchase workflow convergence

`PurchaseScreen` is reorganized around operational intent instead of one long administrative
surface.

The primary workflows are now:

### Belanja Langsung

For purchases where goods are received immediately.

The UI keeps the existing direct-buy authority and makes the stock effect explicit:

- choose supplier;
- choose receiving location;
- add purchase lines;
- review total;
- finish Direct Buy.

The UI states that stock is added only through the existing purchase/goods-receipt authority.

### Pesanan Pemasok

For ordered goods not yet physically received.

The UI explicitly states:

> Pesanan Pemasok belum menambah stok.

This prevents PO creation from being mistaken for inventory receipt.

### Penerimaan Barang

For goods arriving against an existing PO.

The UI separates:

- PO selection;
- remaining PO line;
- received quantity;
- receipt document;
- final **Barang Diterima** posting.

Stock still changes only when the established goods-receipt posting authority posts the receipt.

### Master Data

Supplier and purchase-item creation are grouped away from day-to-day purchase execution so cashier
or operator flow is easier to understand.

### Supplier payable context

Purchase now keeps Supplier Payable visible as an operational consequence without introducing a new
finance writer.

## Inventory control front door

New route:

`/stok/kontrol`

New screen:

`src/screens/InventoryControlScreen.tsx`

New API facade:

`src/inventory/inventory-control-api.ts`

The UI exposes four permission-bounded operations:

- **Minta Restock**
- **Transfer**
- **Stok Opname**
- **Penyesuaian**

Permissions are typed in the frontend authority contract:

- `INVENTORY_REQUEST`
- `INVENTORY_TRANSFER`
- `INVENTORY_COUNT`
- `INVENTORY_ADJUST`

The route, Menu, and shared Operations navigation use the same permission boundary.

## Restock

Restock uses the existing P7 authority:

- `save_restock_request`;
- `submit_restock_request`;
- `approve_restock_request`;
- `reject_restock_request`.

Creating/submitting a restock request does not directly move stock.

Approval creates the canonical transfer workflow according to the existing backend contract.

## Stock transfer

Transfer uses the existing P7 authority:

- `create_stock_transfer`;
- `ship_stock_transfer`;
- `receive_stock_transfer`.

The frontend does not call `record_inventory_movement`.

The operational state is explicit:

```
DRAFT
  -> SHIPPED
  -> RECEIVED
```

and source/destination remain distinct.

## Stock count / opname

Stock count uses the existing P8 authority:

- `create_inventory_count`;
- `record_inventory_count`;
- `post_inventory_count`.

The workflow is:

```
Create snapshot
  -> Expected quantity is server-derived
  -> operator enters physical quantity
  -> review Expected vs Fisik
  -> post variance
```

The frontend does not calculate a replacement stock balance and write it directly.

## Inventory adjustment

Adjustment uses the existing P8 authority:

`post_inventory_adjustment`

The UI requires:

- location;
- stock item;
- adjustment kind;
- signed quantity delta;
- reason;
- optional note.

Backend negative-stock/write-off guards remain authoritative.

No direct table DML or second inventory writer is introduced.

## Packaging / cup control

C5-B makes the earlier packaging decision concrete:

> **Cup/packaging is an ordinary inventory Stock Item.**

The Shift screen links directly to:

`/stok/kontrol?tab=COUNT&kind=PACKAGING`

That surface performs physical count through the same inventory-count authority as every other
stock item.

There is no:

- `cupInventory` writer;
- `cupShift` stock authority;
- second packaging balance table created by C5-B.

## Theoretical packaging evidence

The Shift UI reads theoretical packaging usage from the C2 sale-time immutable component snapshots:

`sale_item_component_snapshots`

filtered by:

`component_role = 'PACKAGING'`

Theoretical usage is display/evidence only.

It does not mutate inventory.

Because the C2 Product/Variant schema is not yet promoted persistently on the current hosted RC1
database, this read is explicitly fail-closed:

```
C2 snapshot relation unavailable
  -> ready = false
  -> truthful "belum dipromosikan" state
  -> Shift remains usable
  -> no invented packaging totals
```

Once the C2 schema is promoted at the RC2 gate, the same UI can expose transaction-derived packaging
usage.

## Shift UX convergence

`ShiftManagementScreen` is reorganized around the operator's actual timeline.

### Opening

The no-open-shift state is now a focused **Buka Shift Baru** surface:

- location;
- opening cash;
- opening source context;
- one primary open-shift action.

### Active Shift

An open shift now shows operational KPI cards:

- Saldo Awal;
- Kas Berjalan;
- Penjualan Tunai;
- Uang Keluar.

These values read the existing shift/reconciliation authority.

### Quick operational actions

The active shift exposes:

- Rekonsiliasi;
- Kontrol Kemasan;
- Handover;
- Lanjut Jual.

### Running reconciliation

The screen exposes the existing reconciliation breakdown:

- cash sale;
- refund;
- cash in;
- cash out;
- adjustment;
- Expected Cash.

QRIS, Transfer, and customer debt are not presented as drawer cash.

### Shift expense

The existing shift-expense authority remains in place, but presentation is grouped into:

- create shift expense;
- approval status;
- posted shift expenses.

### Closing

Closing now visually separates:

- Expected Cash;
- actual cash counted;
- preview variance;
- physical packaging-count reminder;
- final **Tutup Shift** action.

The actual close still uses the existing `closeShift` authority.

## Reconciliation workspace

`ReconciliationScreen` is brought into the shared `OperationsNav` and operations-shell language.

The reconciliation engine is not rewritten.

## Versioned BOM configuration

`ProductOperationsScreen` now exposes an Owner/Production configuration panel when the active
authority has:

`PRODUCTION_MANAGE`

The panel supports:

- PREPRODUCED finished-good selection;
- BOM version;
- yield;
- component lines;
- save draft;
- activate draft BOM.

The API facade calls only the existing versioned authority:

- `save_bom_draft`;
- `activate_bom`.

It uses `requireOnlineAction` for mutation boundaries.

There is no direct `.insert()`, `.update()`, or `.delete()` in the Product operations API.

The existing distinction remains intact:

```
SALE-stage Product/Variant components
!=
versioned production BOM
```

C5-B does not create an ad-hoc sale-stage component writer.

## Read-efficiency hardening

While implementing Inventory Control, the first draft would have read all child rows from:

- restock request lines;
- transfer lines;
- count lines;

before filtering in the browser.

That was hardened before checkpoint.

The client now:

1. reads the bounded latest parent records;
2. collects their IDs;
3. reads only child rows matching those parent IDs.

This avoids recreating the old large-node/read-amplification pattern that previously caused
bandwidth problems in Legacy.

## UI/UX convergence

C5-B extends the C1 design system with responsive, operational structures for:

- Purchase workflow tabs;
- Purchase summary cards;
- receipt cards;
- Stock Control tabs;
- count Expected/Fisik workspace;
- BOM configuration;
- Shift KPI cards;
- Shift quick actions;
- reconciliation breakdown;
- packaging evidence;
- closing summary.

Mobile remains the primary layout while desktop/tablet gain multi-column presentation.

No emoji is introduced as a primary icon system.

## Source changes

New:

- `src/inventory/inventory-control-api.ts`
- `src/screens/InventoryControlScreen.tsx`
- `tests/test_c5b_operations_convergence.py`

Converged:

- `src/App.tsx`
- `src/app.css`
- `src/auth/permission.ts`
- `src/auth/types.ts`
- `src/components/OperationsNav.tsx`
- `src/operations/product-api.ts`
- `src/screens/MenuScreen.tsx`
- `src/screens/ProductOperationsScreen.tsx`
- `src/screens/PurchaseScreen.tsx`
- `src/screens/ReconciliationScreen.tsx`
- `src/screens/ShiftManagementScreen.tsx`
- `src/shift/shift-api.ts`

## Tests and verification

C5-B focused contract after final hardening:

- **12/12 PASS**

The focused suite covers:

- Purchase workflow grouping;
- Shift opening/active/close/reconciliation/packaging surfaces;
- BOM configuration using versioned authority;
- typed inventory-control permissions/routes;
- canonical P7/P8 RPC reuse;
- Restock/Transfer/Count/Adjustment front door;
- shared Menu/Operations navigation;
- packaging as inventory Stock Item;
- theoretical packaging snapshot read and fail-closed behavior;
- shared reconciliation workspace;
- shared design-system contract;
- no C5-B migration.

Full canonical verification after implementation and the Purchase unused-import correction:

- repository guard: PASS;
- formatting: PASS;
- lint: PASS;
- TypeScript typecheck: PASS;
- JavaScript: **96/96 PASS**;
- Python: **269/269 PASS**;
- production build: PASS;
- `git diff --check`: PASS.

A final canonical verification is required again after checkpoint documentation before commit/push.

## Persistent database / deployment impact

**NONE.**

C5-B adds no database migration.

- hosted schema unchanged;
- hosted business data unchanged;
- C2/C3 post-RC1 migrations remain unapplied persistently;
- RC1 tag/commit remain unchanged;
- RC1 Cloudflare Preview remains unchanged;
- no RC2 Preview exists yet;
- Production remains unchanged;
- automatic Production deployment remains disabled.

## Board 03 status after C5-B

The main Board 03 operational surfaces are now source-converged:

```
Persediaan / Detail Barang
        +
Product / Variant / Recipe / Packaging
        +
Purchase
        +
Production
        +
Restock / Transfer / Count / Adjustment
        +
Shift / Reconciliation / Packaging Control
```

Remaining visual/polish findings should now be validated later through the RC2 Preview + Human UAT,
rather than by creating parallel business engines.

## Next safe phase

**C6 — Board 04 Control Center convergence.**

Converge the approved Control Center around real evidence and existing authorities:

- Settings Home;
- Appearance / Dashboard preferences;
- Finance entry points;
- Users / Permissions;
- Active / Trusted Devices;
- actionable Attention;
- Backup & Restore;
- Health;
- Offline / Sync;
- Diagnostics.

Non-negotiable:

- no fake green health/backup state;
- no `navigator.onLine` as backend-health proof;
- no silent AI/service fallback;
- no Owner-global finance leakage to Cashier;
- no automatic Production deployment.

Persistent C2/C3 migration and new Preview remain gated until the dedicated RC2 promotion phase.
