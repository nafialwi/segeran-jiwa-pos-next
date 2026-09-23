# C11-F0A — Product Master Completion Safe Point

Date: 2026-09-23

## Purpose

C11-F0A closes the known Product Master functional gap before final visual QA.
The Product & Recipe screen was previously read-oriented for product/variant
metadata; only versioned production BOM management was writable.

This checkpoint adds a permission-bounded Product Master editor while preserving
the existing sale, inventory, production, finance, shift, refund, correction,
and historical snapshot authorities.

## Product Master capability

A new permission is defined:

- PRODUCT_MANAGE — Kelola Produk Jual

The /produk route remains readable for inventory/production users, but edit
controls are shown only when the current authority has PRODUCT_MANAGE and the
backend capability probe confirms the new RPC authority is installed.

This capability probe intentionally fails closed. A preview connected to an
older backend does not expose a broken editor.

## Editable product fields

Authorized users can create or update:

- product code;
- display name;
- category;
- description;
- active/nonactive sale state.

Product mutation uses save_sale_product_master. The frontend does not receive
direct write access to sale_products.

## Editable variant fields

Authorized users can create or update:

- variant code;
- display name;
- sale price;
- active/nonactive state;
- default variant;
- fulfillment mode: Direct Stock, Make to Order, or Preproduced;
- sale stock item for stock-backed modes;
- sale-stage Ingredient and Packaging components.

For Direct Stock and Preproduced modes the FINISHED_GOOD component is derived
server-side from sale_stock_item_id. Users cannot manually create or replace
that invariant.

For Make to Order, at least one valid sale-stage Ingredient or Packaging
component is required.

Packaging components must point to active PACKAGING Stock Items.
Ingredient components must point to active MATERIAL or OTHER Stock Items.

Production-stage BOM authority remains separate and versioned through the
existing BOM RPCs.

## Historical truth and audit

Product edits affect future transactions only.

Historical sales remain unchanged because sale checkout already stores immutable
product, variant, price, fulfillment, and component snapshots.

The new mutation RPCs are:

- permission checked;
- security-definer with pinned search_path;
- idempotency bounded through the existing operation receipt mechanism;
- audit-event recorded;
- authenticated RPC only;
- not exposed as direct client table DML.

No update/delete is introduced for historical sales, sale lines, or component
snapshots.

## UI/UX

Product & Recipe now has:

- Add Product action for authorized users;
- Manage Product action on the selected product;
- a mobile-first Product Master bottom sheet / desktop modal;
- product information form;
- existing/new variant selector;
- searchable Stock Item picker;
- searchable Ingredient/Packaging component picker;
- human-facing fulfillment labels;
- active/default controls;
- clear statement that edits affect future transactions while historical sales
  retain their original snapshots.

Raw engineering labels in the touched Product screen were reduced where possible.

## Migration status

Migration source prepared:

supabase/migrations/20260923120000_c11f0a_product_master_editor.sql

It is committed as source for controlled schema application later.

It has NOT been applied to Production in this checkpoint.

Because the frontend checks product_master_capability before exposing mutation
controls, the current preview remains fail-closed when connected to an
unmigrated backend.

## Verification

Focused C11-F0A and surrounding C5/C11 operation tests: PASS.

Canonical verification before checkpoint documentation:

- JavaScript: 96/96 PASS;
- Python: 338/338 PASS;
- repository guard: PASS;
- Prettier: PASS;
- ESLint: PASS;
- TypeScript: PASS;
- production build: PASS;
- git diff-check: PASS.

The canonical verification is rerun after this checkpoint documentation before
the safe commit.

## Release status

C11-F0A is a source safe point, not a Production schema deployment.

RC4 remains immutable as the last accepted UAT release candidate.
Production automatic deployment remains disabled.

Next: C11-F0B — Operational Message (Owner/authorized management to Cashier).
