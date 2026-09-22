# C2-C V2 Read Projection Convergence — SAFEPOINT

Date: 2026-09-22

Branch: `work/cs06743-patch3-hardening`

## Outcome

C2-C closes the major downstream-reader gap that prevented safe use of V2 Product/Variant sales.

Reader rule is now explicit:

```
V2 sale line
  -> immutable Product/Variant sale-time snapshot

Legacy sale line
  -> stock_items fallback
```

History, product-oriented reports, and Correction preview no longer assume every sale line must have
a non-null legacy `stock_item_id`.

No business writer is introduced in C2-C.

## Baseline preserved

C2-C started from:

- C2-B safe commit:
  `16181acfd8a7eea91651ba3dd0973d7daa4a0a68`
- branch:
  `work/cs06743-patch3-hardening`
- RC1 remains immutable:
  `uat-rc-20260921-1 -> e844f9b9ad07ca240e1ba4f72a39c6c7aefbb489`
- RC1 Cloudflare Preview remains unchanged.
- Production automatic deployment remains disabled.

## Narrow read-projection audit

Before implementation, the current readers were inspected.

Confirmed legacy assumptions:

1. Transaction History item detail inner-joined
   `sale_items.stock_item_id -> stock_items`.
2. Product search in Transaction History used the same legacy stock-item join.
3. Sales/Product report product sections grouped by `sale_items.stock_item_id`.
4. Correction preview counted tracked lines by joining sale items to stock items.
5. Actual Refund and Correction execution did **not** have this problem because they already reverse
   the original canonical inventory movement.

Therefore C2-C changes readers only, not Refund/Correction execution writers.

## Unified read projection

New private view:

`private.sale_line_read_projection`

It exposes one normalized sale-line shape:

- `sale_id`
- `line_no`
- `stock_item_id` when a legacy/direct stock identity exists
- `sale_product_id`
- `variant_id`
- product code/name
- variant code/name
- fulfillment mode
- category
- `product_key`
- quantity
- unit price
- subtotal

Resolution order:

```
V2
  product_code_snapshot / product_name_snapshot / variant snapshot

Legacy
  stock_items.code / stock_items.display_name
```

The view is private and direct client access is revoked.

## Transaction History convergence

`public.transaction_history_search(...)` now reads
`private.sale_line_read_projection`.

For V2 lines the JSON item includes:

- `sale_product_id`
- `variant_id`
- product code/name
- variant code/name
- fulfillment mode
- category
- quantity / price / subtotal
- nullable `stock_item_id`

Legacy lines keep the existing stock-item identity through the fallback.

Product search now matches:

- product display name;
- product code;
- variant display name;
- variant code.

Therefore a user can find a V2 sale by its variant label even when that sale has no legacy
`stock_item_id`.

## Frontend History type convergence

`src/history/history-api.ts` now accepts the V2 identity shape.

In particular:

- `stock_item_id` is nullable;
- `sale_product_id` is nullable;
- `variant_id` is nullable;
- variant code/name are nullable;
- fulfillment mode is nullable;
- category is nullable.

No History screen redesign is performed in C2-C. The API is now safe for both data generations.

## Sales/Product report convergence

`public.report_run(...)` keeps its existing authority and permission model but its product-oriented
sections now read the unified sale-line projection.

The report no longer groups sale performance by consumed inventory stock item.

Instead it groups by sale Product/Variant identity:

```
V2
  product_key = VARIANT:<variant_id>

Legacy
  product_key = STOCK:<stock_item_id>
```

The report includes a `Varian` column.

This distinction is important:

> Cup, sugar, milk, syrup, packaging, etc. remain inventory components. They do not become
> "products sold" merely because they were consumed by a V2 sale.

Refund and Correction quantities/values use the same immutable sale-line identity as the original
transaction.

## Correction preview convergence

`public.sale_correction_preview(uuid)` no longer estimates stock impact by joining sale lines to
current stock-item metadata.

It counts the actual original `SALE_CONSUMPTION` inventory movement lines.

This makes the preview independent of whether the original sale was:

- legacy direct stock;
- V2 DIRECT_STOCK;
- V2 MAKE_TO_ORDER;
- V2 PREPRODUCED.

Execution remains unchanged: Correction still reverses the original canonical movement.

## Real transactional PostgreSQL rehearsal

C2-A + C2-B + C2-C + the C2-C integration test were executed against the hosted PostgreSQL engine
inside one explicit transaction.

The rehearsal covered:

1. apply C2-A schema in transaction;
2. apply C2-B execution/snapshot schema in transaction;
3. apply C2-C reader convergence in transaction;
4. create isolated authenticated Owner/session/device;
5. create tracked ingredient, packaging, and direct-stock fixture items;
6. create MAKE_TO_ORDER Product + Variant;
7. run V2 checkout;
8. replay the same V2 checkout;
9. run second V2 checkout;
10. run legacy checkout;
11. Refund first V2 sale;
12. Correct second V2 sale;
13. search V2 History by variant name;
14. search legacy History by stock-item/product name;
15. run PRODUCT report and verify both V2 + legacy identities are represented;
16. run Correction preview and verify tracked stock impact comes from the original movement;
17. verify the earlier C2-B movement/balance/reversal assertions;
18. rollback everything.

Result: **PASS**.

Post-rollback verification:

- persisted C2 tables on hosted DB: **0**
- persisted C2/C2C fixture profile: **0**

Therefore no persistent hosted schema or business-data mutation occurred.

## Source/tests added

New migration:

`supabase/migrations/20260922100000_c2c_read_projection_convergence.sql`

New SQL regression:

`supabase/tests/c2c_read_projection_convergence_test.sql`

New Python contract:

`tests/test_c2c_read_projection_convergence.py`

The exact migration/test-history guard is updated.

## Canonical verification

After implementation:

- repository guard: PASS
- format: PASS
- lint: PASS
- TypeScript typecheck: PASS
- JavaScript: **96/96 PASS**
- Python: **226/226 PASS**
- production build: PASS
- `git diff --check`: PASS

C2-C targeted contract:

- **6/6 PASS**

Combined C2-A/C2-B/C2-C/history-guard targeted suite:

- **27/27 PASS**

## Persistent hosted / production impact

**NONE.**

- C2-A/C2-B/C2-C remain source-controlled migrations only.
- hosted operational schema remains unchanged after rehearsal rollback.
- hosted business data remains unchanged.
- RC1 remains unchanged.
- RC1 Cloudflare Preview remains unchanged.
- Production remains unchanged.
- automatic Production deployment remains disabled.

## What C2-C unlocks

The V2 transaction path is now internally coherent across:

```
Product/Variant catalog foundation
  -> V2 checkout
  -> immutable sale snapshot
  -> component inventory posting
  -> History
  -> product reporting
  -> Refund
  -> Correction
```

This removes the primary reader blocker to migrating the Sales frontend.

## Still intentionally not completed

1. SalesScreen still calls legacy `sales_catalog`.
2. SalesScreen still submits legacy `stock_item_id` checkout payload.
3. The C2 migrations are not persistently applied to hosted Supabase.
4. Product/Variant configuration write authority/UI is not complete.
5. Board 02 visual Product/Variant selection and final success/detail presentation are not complete.
6. Discount policy and backend discount facts are not yet converged.
7. Tendered cash/change are not persisted as final sale facts.
8. Owner/Kasir final dashboards, Board 03 operations surfaces, Board 04 Control Center, exact logo,
   RC2 Preview, Human UAT, and cutover remain later phases.

## Next safe phase

**C3-A — Sales Frontend V2 Contract Convergence.**

Scope:

- introduce frontend V2 catalog/API types;
- make Product + Variant the sale-selection identity;
- submit `variant_id + quantity`;
- keep current UI behaviour/functionality stable first;
- preserve offline fail-closed guard;
- preserve idempotent operation ID behavior;
- preserve Cash / manual QRIS / Transfer / Credit semantics;
- add a compatibility boundary/fail-closed behavior for environments where C2 migrations are not yet applied;
- do not perform a hosted persistent migration or Cloudflare deployment until a dedicated RC2
  migration/deployment gate is reached.

C3-A is a contract/front-end convergence step, not yet the full Board 02 visual polish.
