# CS-06-P5 — BOM Foundation — Design Spec

<!-- prettier-ignore-start -->

**Project:** Segeran Jiwa POS Next  
**Date:** 2026-09-15  
**Status:** DESIGN APPROVED IN CHAT — written spec pending user review  
**Blueprint baseline:** v1.0 FINAL LOCK  
**Source baseline entering P5:** `ecad4bcb31a779d943dce20777862a12115be51c`  
**Previous locked milestone:** `CS-06-P4R1-GRN-HARDENING`  
**Workflow authority:** Expert Workstation XP+ 2.1.0  

---

## 1. Purpose

CS-06-P5 establishes Bill of Materials (BOM) as the canonical recipe authority for finished goods.

P5 defines *what* components are required to produce a finished good and how recipe versions are governed. It does **not** post inventory movements and does **not** execute production. Production execution is a later milestone and must consume an immutable ACTIVE BOM version.

The design deliberately preserves the current inventory architecture:

- `stock_items` remains the canonical item master.
- `inventory_movements` + `inventory_movement_lines` remain the canonical stock ledger.
- `inventory_balances` remains a derived projection.
- Direct client DML is not a security boundary.
- Server-side permission checks remain authoritative.

---

## 2. Existing Contracts Carried Forward

### 2.1 Canonical item authority

BOM references `public.stock_items`, not deprecated `products`.

Relevant `stock_items.item_kind` values already present in the source are:

- `MATERIAL`
- `FINISHED_GOOD`
- `PACKAGING`
- `OTHER`

A BOM header may target only an active `FINISHED_GOOD`.

A BOM component may reference an active `MATERIAL`, `PACKAGING`, or `OTHER` item. A finished good may not be used as its own component in P5.

### 2.2 Quantity authority

Recipe quantities are stored in the component stock item's **base unit**.

P5 does not store purchase-unit quantities as the canonical recipe quantity. Purchase conversion changes must not rewrite or reinterpret historical BOM versions.

Because the canonical inventory ledger stores `quantity_delta numeric(18,3)`, P5 component base quantities must be compatible with three-decimal ledger precision. Values requiring greater precision are rejected rather than silently rounded.

### 2.3 Permission authority

All state-changing BOM operations require effective permission:

`PRODUCTION_MANAGE`

Authorization is evaluated server-side with the current membership/session authority through `private.has_permission(...)`.

Owner-level membership continues to inherit permission through the existing permission engine.

### 2.4 Tenant boundary

Every BOM operation is scoped to one `business_id`.

Finished goods, components, units, actor identity, and BOM records must belong to the same business. Cross-business references fail closed.

---

## 3. Scope

### 3.1 In P5

P5 introduces:

1. Versioned BOM headers.
2. BOM component lines.
3. Draft creation/replacement.
4. Atomic BOM activation.
5. Automatic retirement of the previously active BOM for the same finished good.
6. Read visibility under tenant isolation.
7. Server-side `PRODUCTION_MANAGE` enforcement.
8. Immutability rules for activated/retired recipe history.
9. SQL regression coverage.
10. Source-level regression guards for the P5 contract.

### 3.2 Explicitly out of scope

P5 does **not** implement:

- production orders;
- production batch posting;
- material consumption;
- finished-good stock creation;
- shortage calculation/reservation;
- waste/scrap posting;
- production costing/HPP calculation;
- production reversal;
- production UI;
- production reports.

Those belong to subsequent CS-06 production milestones.

---

## 4. Data Model

### 4.1 `public.boms`

Canonical fields:

- `id uuid primary key`
- `business_id uuid not null`
- `finished_good_id uuid not null`
- `version integer not null`
- `status text not null`
- `yield_quantity numeric(18,3) not null`
- `created_by uuid not null`
- `created_at timestamptz not null`
- `activated_by uuid null`
- `activated_at timestamptz null`
- `retired_by uuid null`
- `retired_at timestamptz null`

Allowed status values:

- `DRAFT`
- `ACTIVE`
- `RETIRED`

Constraints:

- `yield_quantity > 0`
- `version > 0`
- unique `(business_id, finished_good_id, version)`
- at most one `ACTIVE` BOM per `(business_id, finished_good_id)`

`finished_good_id` must resolve to an active `stock_items` row with `item_kind = 'FINISHED_GOOD'` in the same business.

### 4.2 `public.bom_lines`

Canonical fields:

- `bom_id uuid not null`
- `line_no integer not null`
- `component_stock_item_id uuid not null`
- `base_quantity numeric(18,3) not null`
- `created_at timestamptz not null`

Primary key:

- `(bom_id, line_no)`

Additional uniqueness:

- one component may appear only once in one BOM.

Constraints:

- `line_no > 0`
- `base_quantity > 0`

The component must:

- belong to the same business as the BOM;
- be active;
- not equal `finished_good_id`;
- be `MATERIAL`, `PACKAGING`, or `OTHER`.

---

## 5. Lifecycle

### 5.1 Create or replace draft

RPC:

`public.save_bom_draft(...)`

Purpose:

- create a new DRAFT version, or
- replace the contents of an existing DRAFT owned by the same BOM identity.

The caller supplies:

- finished good;
- version;
- yield quantity;
- component lines;
- an idempotency key.

Rules:

1. Current actor and business are resolved from canonical authority.
2. `PRODUCTION_MANAGE` is required.
3. The finished good and all components are validated.
4. Every component quantity is already expressed in its base unit.
5. Duplicate components are rejected.
6. A DRAFT may be replaced while it remains DRAFT.
7. ACTIVE and RETIRED BOM content cannot be rewritten.
8. Replaying the same idempotency key with the same payload returns the same result.
9. Reusing an idempotency key with a different payload is rejected by the existing idempotency authority.

### 5.2 Activate BOM

RPC:

`public.activate_bom(p_bom_id uuid, p_idempotency_key text)`

Activation is one atomic transaction.

Rules:

1. Resolve current actor/business.
2. Require `PRODUCTION_MANAGE`.
3. Lock target BOM and the active-BOM slot for the finished good.
4. Target must be DRAFT.
5. BOM must contain at least one valid component line.
6. Revalidate finished good and all component rows.
7. Retire the existing ACTIVE BOM for that finished good, if one exists.
8. Mark target BOM ACTIVE.
9. Record activation actor/time.
10. Record retirement actor/time on the displaced BOM.
11. Return a stable success result.
12. Retry with the same idempotency key is safe and does not create additional state changes.

### 5.3 Immutability

Once a BOM becomes `ACTIVE` or `RETIRED`:

- recipe lines cannot be edited or deleted;
- yield quantity cannot be changed;
- finished good cannot be changed;
- version cannot be changed.

A recipe change requires a new version.

This preserves future production-history reproducibility.

---

## 6. Security Model

### 6.1 Direct privileges

`anon` and `authenticated` must not receive direct INSERT/UPDATE/DELETE authority over BOM tables.

Client writes occur through narrow RPC functions only.

### 6.2 RPC boundary

State-changing RPC functions are:

- `SECURITY DEFINER`;
- `set search_path = ''`;
- fully schema-qualified internally;
- executable by `authenticated`;
- permission-checked with `private.has_permission(business_id, 'PRODUCTION_MANAGE')`.

Granting RPC EXECUTE to `authenticated` is only transport exposure; authorization remains inside the function.

### 6.3 RLS/read scope

BOM tables use tenant-aware RLS for reads based on current canonical authority.

Cross-tenant reads and writes are denied.

---

## 7. Inventory Boundary

P5 must not call `private.record_inventory_movement(...)`.

Creating, replacing, activating, or retiring a BOM changes **recipe metadata only**.

Therefore all P5 regressions must prove that:

- no `inventory_movements` row is created;
- no `inventory_movement_lines` row is created;
- `inventory_balances` is unchanged.

This boundary is mandatory because stock effects belong to Production Execution, not recipe definition.

---

## 8. Error Handling

Expected domain failures use stable error messages suitable for regression tests, including:

- `BOM_PERMISSION_DENIED`
- `BOM_FINISHED_GOOD_INVALID`
- `BOM_VERSION_INVALID`
- `BOM_YIELD_INVALID`
- `BOM_LINES_REQUIRED`
- `BOM_LINE_INVALID`
- `BOM_DUPLICATE_COMPONENT`
- `BOM_SELF_REFERENCE`
- `BOM_NOT_FOUND`
- `BOM_NOT_DRAFT`
- `BOM_CROSS_TENANT`
- `BOM_LEDGER_PRECISION_UNSUPPORTED`

Existing CS-02/CS-03 idempotency and authority errors remain authoritative where applicable.

---

## 9. Regression Strategy

### 9.1 SQL regression

The SQL regression must execute inside rollback-safe test scope and prove:

1. Authorized actor can save a valid DRAFT BOM.
2. Unauthorized actor cannot save or activate BOM.
3. Cross-tenant finished good/component is rejected.
4. Finished-good self-reference is rejected.
5. Duplicate component is rejected.
6. Invalid component kind or inactive component is rejected.
7. Quantity requiring unsupported ledger precision is rejected.
8. Activation changes DRAFT to ACTIVE.
9. Activating a newer version retires the previous ACTIVE version.
10. Exactly one ACTIVE BOM exists per finished good.
11. ACTIVE/RETIRED recipe content cannot be mutated.
12. Idempotent retry returns stable result.
13. BOM operations do not create inventory movements or change inventory balances.

### 9.2 Source-level regression

Python/source guards verify:

- migration is registered by the canonical migration test list used by the repo;
- `PRODUCTION_MANAGE` exists at the write boundary;
- `stock_items` is used rather than deprecated `products`;
- no call to `private.record_inventory_movement()` is present in P5;
- direct client DML grants are not introduced;
- SECURITY DEFINER functions use hardened search path.

### 9.3 Canonical project verification

XP must still run the repository's configured canonical verification after package application.

No P5 lock is accepted if existing verification regresses.

---

## 10. Human QA

Human QA for P5 is backend-oriented.

Required observations:

1. An authorized Owner/production-capable account can create a draft recipe.
2. Activation produces one ACTIVE BOM for the finished good.
3. A new version activation retires the older version.
4. Unauthorized account is rejected.
5. Invalid/self-referential component is rejected.
6. Recipe activation does not change stock.
7. Refresh/re-query reproduces the same active recipe and version.
8. No regression appears in existing purchase/GRN flows.

---

## 11. Forward Contract for P6

P6 Production Execution must consume a specific immutable BOM version.

The expected future flow is:

`Production Order / Batch`
→ bind ACTIVE BOM version
→ calculate component requirements from `yield_quantity`
→ validate stock/location
→ post one canonical inventory movement
→ negative component quantities
→ positive finished-good quantity
→ idempotent result
→ immutable production history.

P6 must use `private.record_inventory_movement(...)`; P5 explicitly must not.

---

## 12. Migration and Change-Control Strategy

P5 is forward-only.

It must not rewrite locked CS-06 P1–P4R1 migrations.

Implementation will add:

- one new forward migration;
- one SQL regression test;
- source-level regression test(s);
- this design document;
- only the minimum migration-registry/test-list adjustment required by the repository's existing conventions.

All source mutation is performed through XP+ package workflow on the existing `work/*` branch. No merge to `main` and no production deployment are part of P5.

---

## 13. Acceptance Gate

P5 may be Final Locked only when:

- schema migration is applied;
- SQL regression is clear;
- canonical project verification is clear;
- Human QA is clear;
- XP creates checkpoint/source archive/SHA;
- remote safepoint succeeds;
- final state is `LOCKED_REMOTE`.

After this gate, CS-06 advances to Production Execution rather than revisiting BOM semantics.

<!-- prettier-ignore-end -->
