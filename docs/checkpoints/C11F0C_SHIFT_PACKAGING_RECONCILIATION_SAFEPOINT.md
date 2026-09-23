# C11-F0C — Shift Packaging Reconciliation Safe Point

Date: 2026-09-23

## Scope

C11-F0C closes the known shift packaging visibility gap without creating a
second cup or packaging inventory engine.

Packaging remains a canonical Stock Item with `item_kind = PACKAGING`.
Physical quantities continue to use the existing Inventory Stock Count
authority. The shift feature only links those canonical count facts to an
OPENING or CLOSING checkpoint and combines them with immutable sale-component
usage snapshots.

## Shift packaging flow

For an active shift, authorized users with `INVENTORY_COUNT` can now create:

- **Opening Fisik** — a packaging stock-count snapshot intended before the
  first sale;
- **Closing Fisik** — a packaging stock-count snapshot intended after the last
  stock-affecting activity and before closing the shift.

The UI shows, per packaging item:

- Awal Fisik;
- Pemakaian Teoritis;
- Expected Closing;
- Fisik Closing;
- Selisih.

The result follows the operational model:

`physical closing - expected closing = variance`.

The system never fabricates a physical quantity. Variance remains unavailable
until a real count has been recorded.

## Opening integrity

Opening cannot be reconstructed after the first sale.

If a shift already has a sale and no valid posted Opening checkpoint exists,
the server returns `SJ_SHIFT_PACKAGING_OPENING_TOO_LATE`. The UI explicitly
tells the cashier to complete Closing for the current shift and begin the next
shift with a proper Opening checkpoint.

A previously posted Opening remains the immutable baseline for the shift.

## Closing freshness

A Closing checkpoint is a point-in-time inventory snapshot.

If a packaging-affecting inventory movement happens after that snapshot, the
projection marks Closing as stale. The UI then offers **Hitung Ulang Closing**.

Old count facts are not deleted or rewritten. A fresh checkpoint supersedes the
old stale snapshot for the reconciliation view.

Posting still goes through the existing `post_inventory_count` authority,
including its balance-change guard.

## Canonical inventory authority

Migration source:

`supabase/migrations/20260923150000_c11f0c_shift_packaging_reconciliation.sql`

The migration extends the existing `public.inventory_counts` table with:

- optional `shift_id`;
- optional `shift_checkpoint` = `OPENING` / `CLOSING`.

The shift link is immutable after count creation.

It does **not** create:

- a cup stock table;
- a packaging balance table;
- a second inventory ledger;
- a parallel packaging movement engine.

Physical count lines continue to live in
`public.inventory_count_lines`, and posting continues through the canonical
Inventory authority.

## Theoretical usage authority

Theoretical packaging use still comes from immutable checkout facts:

`sale_item_component_snapshots` with `component_role = PACKAGING`.

The projection is shift-scoped and business-scoped.

This preserves historical product/variant packaging snapshots even if a recipe
is edited later.

## Permission and scope

Creating a shift packaging count requires:

- authenticated authority;
- `INVENTORY_COUNT`;
- the shift to still be OPEN;
- cashier ownership of the shift or Owner authority;
- valid inventory-location scope for non-owner users.

Only active inventory-tracked PACKAGING Stock Items are inserted into a new
checkpoint count.

## UI behavior

Shift Saya now contains a real **Rekonsiliasi Kemasan** panel.

It includes:

- Opening and Closing checkpoint cards;
- physical-entry fields;
- Save Count and Post actions;
- stale-closing warning;
- per-item reconciliation cards;
- mobile single-column convergence at narrow widths;
- a direct link to Kontrol Stok.

Shift closing is deliberately not silently hard-blocked by this new feature in
this source checkpoint. Instead, the screen exposes the packaging truth and
states that the shift does not invent physical counts. Any future hard closing
gate must be an explicit business-rule decision and UAT item, not a hidden UI
change.

## Compatibility / fail-closed behavior

The new reconciliation RPC is capability-compatible with the current RC4
backend.

If `shift_packaging_reconciliation(uuid)` is missing, the frontend falls back
to the existing C10 `shift_packaging_usage(uuid)` read authority and marks the
new physical reconciliation capability as unavailable.

In that state:

- theoretical usage may still be shown;
- no fake Opening/Closing count is shown;
- no variance is fabricated;
- physical checkpoint actions are unavailable.

The C11-F0C migration is source-prepared only and is **not applied to
Production** at this safe point.

## Verification

Focused F0C + C5B + canonical Inventory Count tests: **33/33 PASS**.

Canonical verification:

- JavaScript: **96/96 PASS**;
- Python: **359/359 PASS**;
- repository guard: PASS;
- Prettier: PASS;
- ESLint: PASS;
- TypeScript: PASS;
- production build: PASS;
- git diff-check: PASS.

Canonical verification is rerun after this checkpoint documentation before the
safe commit.

## Release status

C11-F0C is a source safe point.

RC4 remains immutable as the last accepted UAT release candidate.
Production automatic deployment remains disabled.
C11-F0A, C11-F0B, and C11-F0C migrations remain unapplied to Production.

Next: **C11-F0D — Sales Daily-Use Completion**.
