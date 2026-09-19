# CS-06-P8 — Inventory Operational Controls — Design Spec

<!-- prettier-ignore-start -->

**Project:** Segeran Jiwa POS Next  
**Milestone:** `CS-06-P8-INVENTORY-CONTROLS`  
**Previous gate:** `CS-06-P7-RESTOCK-TRANSFER — LOCKED_REMOTE`  
**Workflow authority:** Expert Workstation XP+ 2.1.0  
**Blueprint baseline:** v1.0 FINAL LOCK  
**Status:** IMPLEMENTATION PACKAGE — bounded CS-06 gap closure  
**Date:** 2026-09-19

---

## 1. Purpose

P8 closes the proven operational-control gap remaining after P7 by adding canonical backend authority for:

1. **Stock Opname** — a location-scoped physical-count session with a server-generated expected-quantity snapshot.
2. **Inventory Adjustment / Write-off** — an explicit, permission-controlled correction fact that writes one canonical inventory movement.
3. **Inventory Control Reversal** — a compensating movement that preserves the original movement and uses the existing `reverses_movement_id` authority.

P8 does not create another stock balance authority. `public.inventory_movements` + `public.inventory_movement_lines` remain authoritative and `public.inventory_balances` remains derived.

## 2. Locked Contracts Carried Forward

- Gudang and Gerai remain separate official stock locations.
- `public.stock_items` remains the canonical inventory item master.
- Every stock change must be represented by a canonical inventory movement.
- `private.record_inventory_movement(...)` remains the only writer used by P8 to change stock.
- Direct authenticated table DML is not an inventory write path.
- Owner is the highest authority.
- Non-Owner inventory-control actions require both permission and P7 `inventory_location_scopes`.
- Completed inventory facts are immutable.
- Retry/double-tap must not duplicate stock movements.
- No silent negative stock.
- P8 is migration-only backend authority; no production deployment or merge to `main` is part of this milestone.

## 3. Permissions

P8 adds:

- `INVENTORY_COUNT` — create/record/post Stock Opname.
- `INVENTORY_ADJUST` — post inventory adjustment/write-off and reverse P8 inventory-control movements.

No permission is granted to Kasir by default. Owner authority remains implicit through the existing permission engine. A non-Owner can receive permission through the existing per-user override mechanism and still requires P7 location scope.

## 4. Stock Opname Authority

### 4.1 Tables

`public.inventory_counts` stores one physical-count session for one location.

States:

`DRAFT -> COUNTED -> POSTED`

`public.inventory_count_lines` stores:

- stock item;
- expected quantity snapshot;
- physical quantity;
- deterministic line number.

The expected quantity is calculated server-side from the canonical ledger when the count is created. It is never supplied by the client.

### 4.2 Stale-snapshot protection

Posting must lock the involved stock-item rows and re-read the canonical ledger.

If current ledger quantity differs from the expected snapshot for any counted item, the whole post fails with:

`INVENTORY_COUNT_BALANCE_CHANGED`

This prevents a physical count from overwriting legitimate stock activity that occurred after the snapshot.

### 4.3 Posting

For each line:

`variance = physical_quantity - expected_quantity`

Only non-zero variances become movement lines.

The single canonical movement uses:

- `movement_type = STOCK_OPNAME`
- `source_type = INVENTORY_COUNT`
- `source_ref = inventory_count.id`
- `reason_code = INVENTORY_COUNT_VARIANCE`

A zero-variance count may become POSTED without creating an empty inventory movement.

## 5. Inventory Adjustment / Write-off

`public.post_inventory_adjustment(...)` creates one immutable `inventory_adjustments` domain fact and exactly one canonical inventory movement.

Kinds:

- `ADJUSTMENT` — positive or negative bounded correction.
- `WRITE_OFF` — negative only.

The caller must provide a non-empty reason code.

Before a negative movement is posted, P8 locks the stock item and verifies:

`current_balance + quantity_delta >= 0`

Otherwise the whole operation fails with:

`INVENTORY_ADJUSTMENT_NEGATIVE_STOCK`

## 6. Inventory Control Reversal

`public.reverse_inventory_control(...)` is limited to movements produced by P8:

- `STOCK_OPNAME`
- `INVENTORY_ADJUSTMENT`
- `INVENTORY_WRITE_OFF`

The original movement is never edited or deleted.

The reversal:

- creates inverse movement lines;
- sets `reverses_movement_id` to the original movement;
- fails if another reversal already exists;
- fails if reversing a positive historical correction would make current stock negative;
- is idempotent through the canonical operation registry.

## 7. Security and Scope

Every state-changing RPC:

- is `SECURITY DEFINER`;
- uses `set search_path = ''`;
- derives business/profile from `public.get_my_authority()`;
- checks `private.has_permission(...)`;
- checks P7 location scope for non-Owner users;
- validates current-business location/item ownership.

Tables are RLS-protected for tenant reads and direct `INSERT/UPDATE/DELETE` is not granted to authenticated users.

## 8. Immutability

- POSTED stock-count headers are immutable.
- Stock-count identity, expected snapshots and item membership are immutable.
- Physical count values may change only before POSTED.
- `inventory_adjustments` are immutable facts.
- Reversal is compensating history, never mutation of the original.

## 9. Explicitly Out of Scope

P8 does **not** implement:

- min-stock recommendation or auto-restock;
- batch/expiry tracking;
- supplier payable/finance settlement;
- receipt discrepancy/damaged/lost workflows;
- partial transfer shipment/receipt;
- full inventory UI;
- notifications;
- reports/printing/Excel;
- HPP/profit;
- production waste/scrap;
- production reversal;
- production-return automation.

These remain subject to the post-P8 CS-06 closure audit and later roadmap buckets.

## 10. Completion Gate

P8 completes only after:

1. source/package validation CLEAR;
2. migration classification `DATA_CHANGE`;
3. explicit DB approval;
4. migration applied successfully;
5. SQL regression CLEAR;
6. canonical source verification CLEAR;
7. Human QA CLEAR;
8. Final Lock;
9. remote safepoint CLEAR;
10. terminal state:

`CS-06-P8-INVENTORY-CONTROLS — LOCKED_REMOTE (100%)`

After P8 locks, run one final bounded CS-06 closure audit. Do not automatically start P9 unless that audit proves a remaining CS-06 blocker.

<!-- prettier-ignore-end -->
