# C2-A Product / Variant / Sale-Component Foundation — SAFEPOINT

Date: 2026-09-22

Branch: `work/cs06743-patch3-hardening`

## Purpose

C2-A creates the forward-only domain foundation required by the revised Segeran Jiwa blueprint:

```
Sale Product
  -> Variant
       -> SALE-stage components
       -> existing stock_items
```

Production-stage recipe authority remains the existing versioned BOM engine:

```
PREPRODUCED finished good
  -> active BOM / bom_lines
  -> production batch
  -> canonical inventory movement
```

This intentionally avoids creating a second production recipe authority.

## Narrow contract audit performed before implementation

The current hosted schema and source were inspected specifically for C2.

Verified current behaviour before C2-A:

- `public.sales_catalog(uuid)` reads sale-enabled `stock_items` directly.
- `private.record_sale(...)` accepts `stock_item_id + quantity`.
- `private.post_sale_transaction(...)` deducts each tracked sold `stock_item_id` directly.
- Refund and correction reverse the original canonical inventory movement rather than inventing a new stock calculation.
- Existing production recipes are versioned through `public.boms` and `public.bom_lines`.
- Existing production posting already uses the canonical inventory writer.

Hosted data snapshot observed during the audit:

- stock_items: **68**
- current sale-enabled stock items: **30**
- sale-enabled + inventory tracked: **15**
- sale-enabled + not inventory tracked: **15**
- stock_items carrying legacy mapping: **68**
- current hosted item_kind values: all **FINISHED_GOOD**
- active BOM rows: **0**
- existing sales rows: **6**

Important interpretation:

The hosted master data is still the compatibility dataset imported from Legacy.
C2-A must therefore preserve current sale behaviour first and must not infer that cups,
ingredients, packaging, or other operational stock are correctly classified merely from
the current `item_kind` values.

## New source migration

`supabase/migrations/20260922080000_c2a_product_variant_foundation.sql`

### New `public.sale_products`

POS presentation identity:

- business
- product code
- display name
- category
- description
- active state
- optional `legacy_stock_item_id` compatibility mapping

This table is not the inventory authority.

### New `public.product_variants`

Variant/size sale configuration:

- product
- variant code/name
- fulfillment mode
- sale price
- optional sale stock item
- default variant
- active state

Supported modes:

- `DIRECT_STOCK`
- `MAKE_TO_ORDER`
- `PREPRODUCED`

Shape rule:

- DIRECT_STOCK / PREPRODUCED require a sale stock item.
- MAKE_TO_ORDER has no sale stock item and is expected to consume configured sale-stage components.

### New `public.variant_sale_components`

Explicit SALE-stage mapping only:

- variant
- stock item
- component role
- quantity per sold unit

Roles:

- `INGREDIENT`
- `PACKAGING`
- `FINISHED_GOOD`

There is deliberately no separate variant production-component table.
Production-stage ingredients and production-stage packaging continue to belong to BOM authority.

## Compatibility backfill

C2-A converts every currently active sale-enabled stock item with a valid positive sale price into:

```
1 sale_product
  -> 1 DEFAULT DIRECT_STOCK variant
       -> 1 FINISHED_GOOD sale component, qty 1
```

No existing stock item is deleted, renamed, reclassified, or rewritten.

This means the current RC1 sale model can be represented in the new domain without changing its
physical stock semantics.

## Additive catalog

New RPC:

`public.sales_catalog_v2(uuid)`

It is additive. The old `public.sales_catalog(uuid)` remains untouched.

Properties:

- requires authenticated business authority;
- requires `SALE_EXECUTE`;
- requires an open shift at the requested location;
- returns Product + Variant identity;
- keeps fulfillment mode visible;
- exposes sale price;
- derives direct/preproduced availability from the linked sale stock item;
- derives make-to-order capacity from tracked SALE-stage components;
- does not write inventory or money.

This RPC is not wired into the current Sales UI yet.
C3 will migrate the frontend only after sale execution itself has converged safely.

## Tenant and DML hardening

The three new tables:

- have RLS enabled;
- expose authenticated tenant-bounded SELECT only;
- revoke direct client DML;
- use tenant-consistency guard triggers for product/variant/component references.

No public write RPC for product configuration is introduced in C2-A.
Configuration writes are intentionally deferred until their permission/idempotency contract is locked.

## Explicit non-changes

C2-A does **not** replace or redefine:

- `private.record_sale`
- `private.post_sale_transaction`
- `public.checkout_sale`
- `public.refund_sale`
- `public.correct_sale`
- `private.record_inventory_movement`
- any finance writer
- any production writer

Therefore current checkout behaviour remains unchanged until C2-B.

## Tests

Added:

- `tests/test_c2a_product_variant_foundation.py`
- `supabase/tests/c2a_product_variant_foundation_test.sql`

The Python contract test verifies:

1. Product / Variant / Sale-component separation exists.
2. Production recipe authority is not duplicated.
3. current sale-enabled stock is compatibility-backfilled as DIRECT_STOCK.
4. C2-A does not replace sale or inventory writers.
5. `sales_catalog_v2` is additive and permission/shift bounded.
6. direct client DML remains fail-closed.
7. SQL regression is transactional.

The exact migration-history and SQL-suite guard were updated to register the new migration/test.

## Verification evidence

Final canonical source verification:

- repository guard: PASS
- format: PASS
- lint: PASS
- TypeScript typecheck: PASS
- JavaScript: **96/96 PASS**
- Python: **212/212 PASS**
- production build: PASS
- git diff --check: PASS

C2-A targeted Python contract:

- **7/7 PASS**

## Hosted database status

**NOT APPLIED.**

C2-A is currently a source-controlled migration and test contract only.
No hosted DDL/data mutation was performed during this checkpoint.

Reason:

- RC1 must remain behaviourally untouched.
- no local PostgreSQL/Supabase runtime is installed on the PC;
- applying the migration directly to the hosted operational database only to validate syntax would
  unnecessarily cross the current safe boundary.

Before C2-A is promoted into an RC2 environment, run an isolated/transactional SQL validation or an
approved migration rehearsal, then apply it through the normal managed migration path.

## Production impact

NONE.

- RC1 remains immutable.
- Cloudflare RC1 preview remains unchanged.
- Production automatic deployment remains disabled.
- hosted Supabase schema/data remains unchanged by C2-A work.
- no real sale, stock, shift, finance, refund, correction, or production fact was mutated.

## Next phase

**C2-B — Sale execution + immutable consumption snapshot convergence.**

Required design:

```
variant_id + sold quantity
  -> validate Product/Variant
  -> snapshot product/variant/price
  -> expand SALE-stage components
  -> aggregate stock quantities
  -> canonical inventory movement (exactly once)
  -> existing finance posting
```

C2-B must preserve:

- idempotency/replay ordering;
- existing payment authority;
- original sale immutability;
- refund/correction reversal of the original inventory movement;
- no double deduction for PREPRODUCED products;
- BOM as the only production-stage recipe authority.

Do not wire SalesScreen to `sales_catalog_v2` until the C2-B execution writer is proven.
