# C3-A Sales Frontend V2 Contract Convergence — SAFEPOINT

Date: 2026-09-22

Branch: `work/cs06743-patch3-hardening`

## Outcome

C3-A moves the cashier Sales frontend from the legacy "sell a stock item" contract to the revised
"sell a Product + Variant" contract.

The runtime source now uses:

```
sales_catalog_v2
  -> Product + Variant catalog identity
  -> cart keyed by variant_id
  -> checkout_sale_v2
  -> variant_id + quantity
```

This is a frontend/API contract convergence checkpoint. It is **not** yet the final Board 02 visual
polish and it is **not deployed**.

## Baseline preserved

C3-A started from:

- C2-C safe commit:
  `763c18074a9fcf334d8beef4a05d54adda6a6224`
- branch:
  `work/cs06743-patch3-hardening`
- immutable RC1:
  `uat-rc-20260921-1 -> e844f9b9ad07ca240e1ba4f72a39c6c7aefbb489`
- RC1 Preview remains:
  `https://5188a6b0.segeran-jiwa-pos-next.pages.dev`
- Production automatic deployment remains disabled.

No persistent C2 migration was applied in C3-A.

## Narrow frontend audit before implementation

The current Sales frontend still had the legacy identity contract:

- catalog RPC: `sales_catalog`;
- catalog identity: `stock_item_id`;
- cart identity: `stock_item_id`;
- stock display: `inventory_tracked + quantity`;
- checkout RPC: `checkout_sale`;
- checkout items: `stock_item_id + quantity`.

The existing safety behavior was also identified and preserved:

- synchronous submit guard;
- stable pending operation ID across retry;
- online-only sale boundary;
- permission-aware QRIS / Transfer / Credit methods;
- manual QRIS confirmation;
- transfer confirmation;
- customer required for Credit;
- existing cash tender/change UX.

## Sales API V2 contract

`src/sales/sales-api.ts` now defines catalog identity with:

- `sale_product_id`;
- `product_code`;
- `product_name`;
- `category_code`;
- `variant_id`;
- `variant_code`;
- `variant_name`;
- `fulfillment_mode`;
- `unit_price`;
- `inventory_managed`;
- `available_quantity`;
- optional `sale_stock_item_id`.

Supported fulfillment modes remain:

- `DIRECT_STOCK`
- `MAKE_TO_ORDER`
- `PREPRODUCED`

`fetchSalesCatalog(...)` now calls:

`public.sales_catalog_v2(uuid)`

`checkoutSale(...)` now calls:

`public.checkout_sale_v2(...)`

and submits:

```
variant_id + quantity
```

rather than `stock_item_id + quantity`.

The frontend-facing function names remain compact so the screen does not need two competing sale
APIs. The backend RPC boundary itself is explicitly V2.

## Fail-closed migration boundary

The hosted operational database still does not persistently contain C2-A/C2-B/C2-C.

Therefore C3-A does **not** silently fall back to the Legacy catalog or Legacy checkout when the V2
RPC is missing.

Missing V2 RPC/schema-cache conditions are surfaced as:

`REFINEMENT_DATABASE_NOT_READY`

with an explicit human-readable message that the sale is blocked and is not redirected to a Legacy
path.

This is intentional.

Why:

A silent fallback would create a dangerous state where the screen appears to sell Product/Variant
while the backend actually records the old stock-item-only transaction shape.

C3-A prefers a visible blocked state until the RC2 migration/deployment gate applies the matching
database contract.

## SalesScreen Product/Variant convergence

`src/screens/SalesScreen.tsx` now:

- loads the V2 catalog through the existing API facade;
- searches product name/code;
- searches variant name/code;
- keeps category filtering;
- keys cart lines by `variant_id`;
- increments/decrements by `variant_id`;
- submits `variant_id + quantity`;
- shows Product name as primary sale identity;
- shows Variant name when it is materially distinct from the compatibility DEFAULT variant;
- uses V2 `inventory_managed / available_quantity` for availability/capacity;
- preserves cart quantity and server-authoritative final stock gate.

For compatibility-backfilled DIRECT_STOCK items where the DEFAULT variant name equals the product
name, the UI does not duplicate the same label.

For true variants, the variant label is visible.

## Availability semantics

The old screen assumed:

```
inventory_tracked + stock item quantity
```

The new screen uses:

```
inventory_managed + available_quantity
```

This permits the same frontend contract to represent:

- DIRECT_STOCK availability from the direct item;
- PREPRODUCED availability from the finished good;
- MAKE_TO_ORDER capacity derived by the V2 catalog from tracked sale-stage components.

The frontend availability check is only a UX guard.

The definitive concurrency-safe stock gate remains in the C2-B post-sale transaction writer.

## Safety behavior preserved

C3-A preserves:

- `requireOnlineAction('Penjualan')`;
- synchronous `submitGuardRef`;
- stable `pendingOperationIdRef`;
- operation ID sent as `p_operation_id`;
- CASH;
- manual QRIS confirmation;
- TRANSFER confirmation;
- CREDIT/customer flow;
- permission-aware payment method visibility;
- current retry/idempotency behavior.

No offline sale queue is introduced.

No automatic payment fallback is introduced.

No automatic switch to Legacy sale execution is introduced.

## Cash tender/change note

The current UI still allows cashier entry of:

- Uang diterima;
- Kembalian.

C3-A intentionally does not claim that those are final persisted backend facts.

The V2 checkout still sends the sale total as the payment amount, consistent with the current
server contract.

Persistent `tendered/change` facts belong to a later sale-fact convergence phase.

## Visual scope

C3-A adds only the minimum Product/Variant visual distinction needed for a truthful V2 contract.

It does **not** yet claim final Board 02 completion.

Still deferred:

- grouped Product -> explicit Variant chooser interaction;
- Favorit/Terlaris final behavior;
- final cart hierarchy;
- line-level note contract;
- final payment layout;
- single authoritative success screen;
- final transaction-detail visual treatment;
- discount policy/facts;
- persisted tendered/change facts.

## Tests

New contract test:

`tests/test_c3a_sales_frontend_v2.py`

It verifies:

1. Product/Variant catalog types exist.
2. catalog calls `sales_catalog_v2`.
3. missing C2 schema is fail-closed, not Legacy-fallback.
4. checkout calls `checkout_sale_v2`.
5. checkout submits `variant_id + quantity`.
6. cart identity is Variant, not stock item.
7. Product/Variant search and visible variant labeling exist.
8. V2 availability fields are used.
9. online/idempotency/payment guards remain present.

C3-A targeted test result:

- **7/7 PASS**

Relevant existing Sales/UAT compatibility tests:

- C3-A + POS mobile V2 + UAT core recovery: **15/15 PASS**

## Canonical verification

Before checkpoint documentation:

- repository guard: PASS
- format: PASS
- lint: PASS
- TypeScript typecheck: PASS
- JavaScript: **96/96 PASS**
- Python: **233/233 PASS**
- production build: PASS
- `git diff --check`: PASS

A final canonical verification is required again after this checkpoint document is written, before
the commit is pushed.

## Database / deployment impact

Persistent impact: **NONE**.

C3-A changes frontend/runtime source only.

- C2 migrations remain source-controlled and unapplied persistently.
- hosted schema remains unchanged.
- hosted business data remains unchanged.
- RC1 remains unchanged.
- RC1 Preview remains unchanged.
- no Cloudflare Preview was created.
- Production remains unchanged.
- automatic Production deployment remains disabled.

Because the current hosted DB does not yet have C2, this C3-A source must **not** be deployed by
itself. The matching database migrations and frontend must be promoted together at the dedicated RC2
gate.

## Current end-to-end refinement chain

```
C1-A AppShell / icon foundation
  -> C2-A Product / Variant domain
  -> C2-B V2 sale execution + immutable consumption snapshot
  -> C2-C V2 History / Reports / Correction readers
  -> C3-A Sales frontend Product/Variant contract
```

The sale path is now coherent in source from Product/Variant selection through checkout, stock,
money, history, reports, refund and correction.

## Next safe phase

**C3-B — Sales Facts & Board 02 Checkout Convergence.**

Before declaring the Sales experience visually final, converge the remaining facts that Board 02
shows but the backend does not yet preserve as first-class history:

- cash `tendered` and `change`;
- discount policy/permission + immutable discount facts;
- decide/lock line-note semantics before exposing final line-note UX;
- final single success authority;
- then complete Product/Variant chooser + cart/payment visual convergence.

Do not deploy or persistently migrate hosted C2/C3 source until the dedicated RC2 promotion gate.
