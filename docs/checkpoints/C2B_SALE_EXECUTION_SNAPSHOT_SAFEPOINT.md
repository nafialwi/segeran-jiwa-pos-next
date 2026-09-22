# C2-B Sale Execution & Immutable Consumption Snapshot — SAFEPOINT

Date: 2026-09-22

Branch: `work/cs06743-patch3-hardening`

## Outcome

C2-B establishes a proven, additive variant-based sale execution path without switching the
current RC1 frontend and without creating a second inventory or money ledger.

The core execution shape is now:

```
Product / Variant
  -> immutable sale-line snapshot
  -> immutable SALE-stage component snapshot
  -> aggregate by stock item
  -> definitive stock gate
  -> canonical inventory movement
  -> existing canonical money movement
```

Legacy checkout remains available during convergence.

## Baseline preserved

C2-B started from:

- C2-A safe commit: `a3455b61ce9e6b4cf08e45127b6cafd2639d6315`
- branch: `work/cs06743-patch3-hardening`
- RC1 tag/commit remains unchanged:
  `uat-rc-20260921-1 -> e844f9b9ad07ca240e1ba4f72a39c6c7aefbb489`
- RC1 Cloudflare Preview remains the old RC1 candidate.
- Production automatic deployment remains disabled.

## Narrow dependency audit before implementation

The audit reconfirmed:

1. current `sale_items.stock_item_id` was mandatory;
2. current History/Reports still inner-join `sale_items.stock_item_id -> stock_items`;
3. current Correction preview counts tracked lines through the same legacy join;
4. actual Refund and Correction execution already reverse the **original inventory movement**;
5. the canonical inventory movement writer uses immutable movement facts;
6. `inventory_balances` is a derived view from movement lines;
7. current sale posting owns the single sale money-posting path.

This produced an important design decision:

> Make-to-order sale lines must not invent a fake stock item merely to satisfy the old
> `sale_items.stock_item_id NOT NULL` shape.

Instead, C2-B makes the legacy stock-item reference optional for V2 lines and stores explicit
product/variant/component snapshots.

## New migration

`supabase/migrations/20260922090000_c2b_sale_execution_snapshot.sql`

### Sale-line historical snapshots

`public.sale_items` now has forward-compatible nullable V2 fields:

- `sale_product_id`
- `variant_id`
- `product_code_snapshot`
- `product_name_snapshot`
- `variant_code_snapshot`
- `variant_name_snapshot`
- `fulfillment_mode_snapshot`

`stock_item_id` becomes nullable only so MAKE_TO_ORDER lines do not require a fake stock item.

Existing legacy rows remain valid.

### Immutable component facts

New table:

`public.sale_item_component_snapshots`

Each sale-time component stores:

- sale + sale-line identity;
- component line;
- stock item;
- component role;
- quantity per sold unit;
- final total quantity consumed by that sale line;
- sale-time `inventory_tracked` state;
- stock item code snapshot;
- stock item name snapshot.

The table is protected by the existing immutable-fact trigger.

This is the historical source needed so later changes to recipe/packaging configuration cannot
change what an old transaction means.

## Variant checkout writer

New private writer:

`private.record_sale_v2(...)`

Input contract is based on:

```
variant_id + quantity
```

It:

- requires `SALE_EXECUTE`;
- requires the current cashier to have an OPEN shift;
- validates payment permissions;
- uses an operation-level idempotency receipt;
- resolves current Product + Variant only for a new operation;
- validates variant component shape;
- snapshots Product/Variant identity and price;
- snapshots every SALE-stage component;
- rejects unsupported >3-decimal ledger precision;
- writes the existing `sales`, `sale_items`, and `payments` authorities.

Replay occurs through the existing operation receipt and does not recompute a prior sale from
newer product configuration.

## One post-sale engine retained

`private.post_sale_transaction(...)` remains the single sale posting engine.

It now chooses one inventory basis:

- `SNAPSHOT_V2` when immutable component snapshots exist;
- `LEGACY_SALE_ITEM` when they do not.

For V2:

```
all sold lines
  -> component snapshots
  -> aggregate same stock_item across the whole cart
  -> one inventory movement
```

The canonical inventory writer is still called exactly once per sale posting.

The existing canonical money writer is unchanged in meaning:

- CASH -> KAS_SHIFT
- QRIS -> QRIS_BELUM_CAIR
- TRANSFER -> BANK
- CREDIT -> HUTANG_PELANGGAN

No second finance engine was created.

## Definitive concurrency-safe stock gate

C2-B strengthens the shared post-sale writer for both V2 and legacy sale posting.

Before stock is consumed, tracked stock items are locked in deterministic stock-item order using
transaction-scoped advisory locks.

After acquiring each lock, the current authoritative inventory balance is checked again.

This closes the race where two devices could both pass an earlier availability read before either
movement was posted.

Replay remains safe because the SALE_POSTING idempotency replay exits before this post-sale stock
check.

## Additive public checkout

New RPC:

`public.checkout_sale_v2(uuid, uuid, jsonb, jsonb, text)`

It composes:

```
record_sale_v2
  -> post_sale_transaction
```

The original `public.checkout_sale(...)` is **not replaced or removed**.

This matters because the current SalesScreen is still the RC1 compatibility frontend.

## Refund and Correction compatibility

C2-B does not reimplement Refund or Correction.

Existing authorities continue to reverse the original posted inventory movement.

Because a V2 sale posts its ingredient/packaging/finished-good consumption into that same canonical
inventory movement, the existing reversal logic naturally restores/reverses the exact sale-time
movement rather than consulting today's recipe.

This was verified in the real transactional rehearsal.

## Real transactional PostgreSQL rehearsal

C2-A + C2-B + the C2-B integration test were executed against the hosted PostgreSQL engine inside
one explicit transaction:

```
BEGIN
  -> apply C2-A DDL in transaction
  -> apply C2-B DDL in transaction
  -> create isolated test identity / shift / stock / variant
  -> run V2 checkout
  -> replay same operation
  -> run second V2 checkout
  -> run legacy checkout
  -> Refund first V2 sale
  -> Correct second V2 sale
  -> verify movements / snapshots / balances
ROLLBACK
```

Result: **PASS**.

Verified real behavior included:

- MAKE_TO_ORDER sale has no fake `stock_item_id`;
- ingredient and packaging quantities are snapshotted correctly;
- multiple component facts aggregate into one canonical sale inventory movement;
- retry/replay does not duplicate inventory posting;
- legacy checkout still posts through the fallback basis;
- Refund reverses the original V2 component movement;
- Correction reverses the original V2 component movement;
- final inventory balances reconcile exactly.

Rollback verification after the rehearsal:

- persisted C2 tables on hosted DB: **0**
- persisted C2B fixture profile: **0**

Therefore the hosted operational schema/data was not changed by the rehearsal.

## Tests added

- `tests/test_c2b_sale_execution_snapshot.py`
- `supabase/tests/c2b_sale_execution_snapshot_test.sql`

The Python contract adds **8** C2-B checks.

The SQL integration test is transactional and covers the actual business flow described above.

The exact migration/test history guard is updated for C2-B.

## Canonical verification

After implementation:

- repository guard: PASS
- format: PASS
- lint: PASS
- TypeScript typecheck: PASS
- JavaScript: **96/96 PASS**
- Python: **220/220 PASS**
- production build: PASS
- `git diff --check`: PASS

## Hosted / production impact

Persistent impact: **NONE**.

C2-A and C2-B are still source-controlled migrations only.

- hosted schema is unchanged;
- hosted business data is unchanged;
- RC1 is unchanged;
- Cloudflare Preview is unchanged;
- Production is unchanged;
- automatic production deployment remains disabled.

## Known deferments after C2-B

C2-B intentionally does not yet switch the application to V2 sales.

Still unresolved before V2 sales may be enabled in RC2:

1. Transaction History item projection still assumes a non-null sale stock item.
2. Product Reports still group products by legacy `stock_item_id`.
3. Correction preview tracked-line count still uses the legacy sale-item/stock-item join.
4. SalesScreen still requests `sales_catalog`, not `sales_catalog_v2`.
5. SalesScreen still submits `stock_item_id`, not `variant_id`.
6. Product/Variant configuration write RPCs are not opened yet.
7. Discount and tendered/change persistence remain later Sales convergence work.
8. Exact final product/variant/recipe/packaging UI from Board 02/03 is not complete.

## Next safe phase

**C2-C — V2 Read Projection Convergence.**

Before the frontend can switch, update read-only downstream authorities so both legacy and V2 sales
remain visible and correct:

- Transaction History;
- product search in history;
- Product Reports;
- Refund/Correction transaction-detail item projection;
- Correction preview tracked inventory count.

Reader rule:

```
V2 line -> immutable product/variant snapshot
Legacy line -> stock_items fallback
```

No writer redesign is required in C2-C.

After C2-C is proven, proceed to frontend/API switch and Board 02 visual Sales convergence.
