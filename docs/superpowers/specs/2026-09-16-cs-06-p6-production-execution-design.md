# CS-06-P6 — Production Execution — Design Spec

<!-- prettier-ignore-start -->

**Project:** Segeran Jiwa POS Next
**Milestone:** `CS-06-P6-PRODUCTION-EXECUTION`
**Previous gate:** `CS-06-P5-BOM-FOUNDATION — LOCKED_REMOTE`
**Workflow:** Expert Workstation XP+ 2.1.0
**Status:** Design approved in chat; written-spec review gate

## 1. Purpose

P6 turns the immutable BOM authority from P5 into real production stock movement.

A production batch:

- belongs to exactly one business;
- executes at exactly one active location;
- binds one immutable BOM version when the batch is created;
- consumes BOM components from that same location;
- produces the finished good into that same location;
- posts all inventory effects atomically through the canonical inventory writer;
- rejects insufficient component stock;
- is idempotent;
- becomes immutable after posting.

P6 is backend production execution only. It does not add production UI, costing/HPP, waste/scrap, reversal, multi-location input, or production reporting.

## 2. Locked Contracts Carried Forward

P6 must preserve these existing authorities:

- `public.stock_items` is the canonical item master.
- `public.boms` + `public.bom_lines` are the canonical recipe authority.
- ACTIVE and RETIRED BOM recipe content is immutable.
- `public.inventory_movements` + `public.inventory_movement_lines` are the canonical stock facts.
- `public.inventory_balances` is derived from the immutable ledger.
- Inventory writes occur only through `private.record_inventory_movement(...)`.
- Production writes require `PRODUCTION_MANAGE`.
- Tenant authority comes from `public.get_my_authority()`.
- Direct authenticated DML is not allowed as the production write path.

## 3. Single-Location Production Rule

Each production batch stores one `location_id`.

That location may be either:

- `WAREHOUSE` / Gudang, or
- `STORE` / Gerai.

The location must be active and belong to the current business.

All component consumption and finished-good output for one batch use that same `location_id`.

P6 does not consume material from multiple locations in one batch.

Transfers between Gudang and Gerai remain a separate inventory workflow.

## 4. Data Model

### 4.1 `public.production_batches`

Fields:

- `id uuid primary key`
- `business_id uuid not null`
- `location_id uuid not null`
- `finished_good_id uuid not null`
- `bom_id uuid not null`
- `planned_output numeric(18,3) not null`
- `actual_output numeric(18,3) null`
- `status text not null default 'DRAFT'`
- `inventory_movement_id uuid null`
- `created_by uuid not null`
- `created_at timestamptz not null`
- `posted_by uuid null`
- `posted_at timestamptz null`
- `updated_at timestamptz not null`

Status values in P6:

- `DRAFT`
- `POSTED`

Constraints:

- `planned_output > 0`
- `actual_output is null or actual_output > 0`
- one movement can belong to at most one production batch
- `inventory_movement_id` must be present after POSTED
- `actual_output`, `posted_by`, and `posted_at` must be present after POSTED

No production batch detail table is required in P6 because:

1. `bom_id` points to an immutable recipe version;
2. the posted `inventory_movement_lines` are the immutable actual stock effect.

## 5. Batch Creation

RPC:

`public.create_production_batch(p_location_id uuid, p_finished_good_id uuid, p_planned_output numeric, p_idempotency_key text) -> jsonb`

Rules:

1. Resolve `business_id` and `profile_id` through canonical authority.
2. Require `PRODUCTION_MANAGE`.
3. Validate the requested location belongs to the business and is active.
4. Validate the finished good belongs to the business, is active, and has `item_kind = 'FINISHED_GOOD'`.
5. Validate planned output is positive and compatible with ledger precision.
6. Resolve the currently ACTIVE BOM for that finished good in the same business.
7. Lock that ACTIVE BOM while the batch is being created.
8. Save the selected `bom_id` into the batch.
9. Use the existing idempotency authority so retry returns the same batch.
10. Return batch id, BOM id/version, location, finished good, and DRAFT status.

The batch remains bound to that BOM even if a newer BOM is activated later.

## 6. BOM Version Binding

BOM activation after batch creation must not rewrite the batch.

Example:

- V1 is ACTIVE.
- Batch A is created and binds V1.
- V2 becomes ACTIVE and V1 becomes RETIRED.
- Batch A still posts using V1.
- A later Batch B binds V2.

This gives reproducible production history without duplicating recipe lines into another snapshot table.

## 7. Production Posting

RPC:

`public.post_production_batch(p_batch_id uuid, p_actual_output numeric) -> jsonb`

Posting rules:

1. Resolve current authority.
2. Require `PRODUCTION_MANAGE`.
3. Lock the production batch row.
4. Batch must belong to the current business.
5. If already POSTED:
   - the same actual output returns an idempotent success;
   - a different actual output is rejected.
6. DRAFT batch must reference a valid immutable BOM.
7. Validate actual output is positive and compatible with ledger precision.
8. Lock every BOM component `stock_items` row in deterministic UUID order.
9. Re-read component balances after locks are acquired.
10. Calculate required component quantities from the bound BOM.
11. Reject the whole operation if any component is insufficient.
12. Build one canonical inventory movement:
    - all components: negative quantity;
    - finished good: positive actual output;
    - all lines: same batch location.
13. Call `private.record_inventory_movement(...)` exactly once.
14. Update batch to POSTED and store the movement id, actual output, actor, and timestamp.
15. Return one stable success response.

The production post is one database transaction. It may not commit component consumption without finished-good output, or vice versa.

## 8. Quantity Calculation

For every BOM component:

`raw_required = bom_line.base_quantity * actual_output / bom.yield_quantity`

P6 normalizes the inventory delta to the ledger's three-decimal precision.

Requirements:

- resulting consumption must remain greater than zero;
- no component may silently disappear because rounding produces zero;
- the finished-good output equals `actual_output`;
- inventory movement lines use `numeric(18,3)` values.

If the requested batch is below meaningful ledger precision, reject it with a stable production precision error.

## 9. Stock Availability and Concurrency

A simple balance check without locking is not sufficient because another sale or production post could consume the same item concurrently.

P6 therefore locks component `stock_items` rows using `FOR UPDATE`, ordered by component id, before reading the canonical ledger balance.

This provides a serialization point around component items. Existing inventory movement lines reference `stock_items` through a foreign key, so concurrent inventory inserts touching the same item cannot pass the referenced-row locking point while P6 holds the stronger row lock.

After acquiring the locks, P6 calculates current quantity directly from:

- `inventory_movements`
- `inventory_movement_lines`

filtered by:

- current business;
- component stock item;
- production location.

If any balance is below the calculated requirement:

- no inventory movement is recorded;
- batch remains DRAFT;
- the function raises `PRODUCTION_STOCK_INSUFFICIENT`.

Locks are acquired in deterministic item-id order to reduce deadlock risk.

## 10. Inventory Movement Contract

Production uses the existing canonical writer:

`private.record_inventory_movement(...)`

P6 movement metadata:

- idempotency key: `PRODUCTION_POST:<production_batch_id>`
- `movement_type = 'PRODUCTION'`
- `source_type = 'PRODUCTION_BATCH'`
- `source_ref = production_batch_id::text`
- `reason_code = 'PRODUCTION_POSTED'`

Movement line ordering is deterministic:

1. component lines ordered by BOM `line_no`;
2. finished-good output is the last line.

Exactly one movement is allowed per successfully posted production batch.

## 11. Idempotency

### Create

`create_production_batch(...)` uses the caller idempotency key plus deterministic payload hashing.

Same key + same payload:

- return same batch.

Same key + different payload:

- reject through existing CS-02 idempotency protection.

### Post

Production posting uses the batch id as the canonical posting identity.

Retry of an already-posted batch with the same actual output:

- returns success;
- returns the same movement id;
- creates no duplicate movement.

Retry with a different actual output:

- fails with `PRODUCTION_ALREADY_POSTED_MISMATCH`.

## 12. Immutability

Direct table DML for `anon` and `authenticated` is revoked.

A trigger guards POSTED production facts.

After POSTED, these may not change:

- business;
- location;
- finished good;
- BOM;
- planned output;
- actual output;
- movement id;
- creator;
- posted actor/time.

Production reversal is not implemented in P6. A future reversal milestone must create compensating ledger facts rather than editing the posted batch or movement.

## 13. Security

State-changing RPCs are:

- `SECURITY DEFINER`;
- `set search_path = ''`;
- fully schema-qualified internally;
- exposed to `authenticated`;
- internally gated by `private.has_permission(v_business, 'PRODUCTION_MANAGE')`.

Cross-tenant references fail closed.

The caller may not override:

- `business_id`;
- actor profile;
- BOM id selected during batch creation;
- inventory movement id;
- posting metadata.

## 14. Stable Domain Errors

P6 uses stable errors for regression tests:

- `SJ_AUTHORITY_DENIED`
- `SJ_PRODUCTION_PERMISSION_DENIED`
- `PRODUCTION_LOCATION_INVALID`
- `PRODUCTION_FINISHED_GOOD_INVALID`
- `PRODUCTION_ACTIVE_BOM_REQUIRED`
- `PRODUCTION_OUTPUT_INVALID`
- `PRODUCTION_LEDGER_PRECISION_UNSUPPORTED`
- `PRODUCTION_BATCH_NOT_FOUND`
- `PRODUCTION_BATCH_NOT_DRAFT`
- `PRODUCTION_ALREADY_POSTED_MISMATCH`
- `PRODUCTION_STOCK_INSUFFICIENT`
- `PRODUCTION_BOM_INVALID`
- `PRODUCTION_IMMUTABLE`

Existing CS-02 inventory/idempotency errors remain authoritative where applicable.

## 15. Explicitly Out of Scope

P6 does not implement:

- multi-location component sourcing;
- warehouse-to-store transfer;
- material reservation;
- production scheduling;
- waste or scrap;
- yield variance analytics;
- production HPP/costing;
- production reversal;
- production UI;
- production reporting.

These must not be smuggled into the P6 migration.

## 16. SQL Regression Acceptance

The rollback-safe SQL integration test must prove at least:

1. Owner/authorized actor can create a DRAFT batch.
2. Batch binds the ACTIVE BOM version at creation.
3. Activating a newer BOM does not change an existing batch's bound BOM.
4. Posting consumes components at the batch location.
5. Posting adds the finished good at the same location.
6. Component consumption is calculated from the bound BOM, not the newest BOM.
7. Exactly one inventory movement is created.
8. Retry with same actual output is idempotent.
9. Retry with different actual output is rejected.
10. Insufficient component stock rejects the whole post.
11. Failed insufficient-stock post leaves all balances unchanged.
12. Cashier/account without `PRODUCTION_MANAGE` cannot create or post.
13. Invalid/cross-tenant/inactive location is rejected.
14. Batch is immutable after POSTED.
15. Existing P5 BOM and P4R1 GRN behavior remains compatible.

The test runs inside `begin; ... rollback;`.

## 17. Source-Level Regression

A Python/source contract test must assert:

- P6 tables/RPCs exist;
- `PRODUCTION_MANAGE` is enforced at both write boundaries;
- `private.record_inventory_movement(` is called by the posting RPC;
- exactly one canonical production movement contract is present;
- all movement lines use the batch location;
- stock insufficiency guard exists;
- component row locking exists;
- POSTED immutability exists;
- no direct authenticated DML grant is introduced;
- hardened `search_path` is present;
- migration/test history includes P6.

## 18. Mandatory Anti-Repeat Preflight

P6 must not be packaged until all of these pass.

### 18.1 Format gate

The exact source tree that will be packaged must pass the repository format contract.

Design and plan Markdown shipped through XP will be written in Prettier-stable form. If deterministic formatting cannot be reproduced outside the repo, their body is protected with Prettier's supported ignore-range comments before packaging.

No package is released with a known `format:check` failure.

### 18.2 XP SQL classifier gate

The P6 source-level test must mirror the relevant XP+ 2.1.0 classifier rules.

The raw migration must not contain patterns that XP classifies as:

- `DESTRUCTIVE`
- `NON_TRANSACTIONAL`
- `UNKNOWN`

In particular, the migration source must not contain:

- `DELETE FROM`
- `DROP TABLE`
- `DROP SCHEMA`
- `DROP DATABASE`
- `DROP COLUMN`
- `TRUNCATE`
- `CREATE INDEX CONCURRENTLY`
- `DROP INDEX CONCURRENTLY`
- `VACUUM`
- `REINDEX CONCURRENTLY`

The expected XP classification for P6 is:

`DATA_CHANGE`

If a future implementation needs delete-like reconciliation, use a classifier-safe SQL form such as `MERGE ... WHEN MATCHED THEN DELETE`, subject to regression coverage.

### 18.3 Package scope gate

The final WORK package must contain only approved P6 paths.

No unrelated source file may change.

### 18.4 Replay gate

Before delivery to the human:

1. apply the generated operations to an isolated copy of the locked source;
2. run focused P6 tests;
3. run P5/P4R1 compatibility tests;
4. run exact-history tests;
5. inspect migration classification;
6. validate spec JSON;
7. verify each operation path is inside `allowed_paths`.

### 18.5 Database honesty gate

Local static tests are not reported as live-DB success.

The database migration and SQL integration regression are considered successful only when XP executes them against the configured PostgreSQL database and reaches `HUMAN_QA`.

## 19. Human QA

P6 Human QA confirms:

1. authorized production batch creation is accepted;
2. the batch shows the BOM version captured at creation;
3. production posting consumes expected components;
4. finished-good stock increases at the same location;
5. retry does not duplicate stock movement;
6. insufficient stock is rejected;
7. unauthorized actor is rejected;
8. posted production remains immutable;
9. BOM and purchase/GRN regression remain clear.

Because P6 is backend-first, automated SQL evidence is the primary transactional evidence until production UI exists.

## 20. XP Acceptance Gate

P6 is complete only after:

- source verification CLEAR;
- SQL migration classified `DATA_CHANGE`;
- database approval;
- migration applied successfully;
- SQL regression CLEAR;
- Human QA CLEAR;
- Final Lock;
- remote safepoint CLEAR;
- terminal state `LOCKED_REMOTE (100%)`.

No merge to `main` and no production deployment are part of P6.

<!-- prettier-ignore-end -->
