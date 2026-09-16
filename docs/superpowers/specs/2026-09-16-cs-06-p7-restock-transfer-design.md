# CS-06-P7 — Restock Request & Stock Transfer — Design Spec

<!-- prettier-ignore-start -->

**Project:** Segeran Jiwa POS Next  
**Milestone:** `CS-06-P7-RESTOCK-TRANSFER`  
**Previous gate:** `CS-06-P6-PRODUCTION-EXECUTION — LOCKED_REMOTE`  
**Workflow authority:** Expert Workstation XP+ 2.1.0  
**Blueprint baseline:** v1.0 FINAL LOCK  
**Status:** DESIGN APPROVED IN CHAT — written-spec review gate  
**Date:** 2026-09-16

---

## 1. Purpose

P7 establishes the canonical backend authority for two distinct domains:

1. **Restock Request** — an operational request for stock to be supplied to a destination location.
2. **Stock Transfer** — the physical movement of stock between official inventory locations.

Restock Request never changes inventory directly. Approval may create and link exactly one Stock Transfer. Stock Transfer changes inventory only through the existing canonical inventory movement authority.

P7 supports Gudang → Gerai, Gerai → Gudang, direct Owner transfer without a preceding request, permission-based staff access, location-scoped ship/receive authority, deterministic idempotency, and full shipment/full receipt only.

P7 does not create a second stock engine.

## 2. Locked Contracts Carried Forward

- `public.stock_items` remains the canonical item master.
- `public.inventory_movements` + `public.inventory_movement_lines` remain the canonical stock ledger.
- `public.inventory_balances` remains a derived projection.
- All inventory changes use `private.record_inventory_movement(...)`.
- Direct client DML is not the stock authority.
- Stock may not silently go negative.
- Gudang and Gerai remain separate official inventory locations.
- No third official inventory location named TRANSIT is introduced.
- Existing authorization remains: `Owner hard boundary → role preset → per-user override → resource scope`.

Existing permission `INVENTORY_TRANSFER` remains the canonical permission for transfer actions. P7 adds `INVENTORY_REQUEST` for creating/submitting Restock Requests. Kasir does not receive `INVENTORY_TRANSFER` by default.

## 3. Approved Domain Separation

```text
RESTOCK REQUEST
DRAFT
  ↓ submit
SUBMITTED
  ├─ reject → REJECTED
  └─ approve → APPROVED ── creates/links exactly one DRAFT Stock Transfer

STOCK TRANSFER
DRAFT
  ↓ ship
SHIPPED
  ↓ receive
RECEIVED
```

Request approval and physical stock movement remain separate authorities. A future Gudang role can use Stock Transfer directly without being forced through Restock Request.

## 4. No Partial Fulfillment in P7

P7 supports full shipment and full receipt only.

One transfer ships every line in full together and receives every shipped line in full together. P7 does not support partial shipment, partial receipt, split fulfillment, line-by-line receipt, or receipt discrepancy resolution.

## 5. Restock Request Data Model

### 5.1 `public.restock_requests`

Fields:

- `id uuid primary key`
- `business_id uuid not null`
- `destination_location_id uuid not null`
- `requester_profile_id uuid not null`
- `status text not null default 'DRAFT'`
- `notes text null`
- `transfer_id uuid null`
- `created_at timestamptz not null`
- `updated_at timestamptz not null`
- `submitted_at timestamptz null`
- `approved_at timestamptz null`
- `approved_by uuid null`
- `rejected_at timestamptz null`
- `rejected_by uuid null`
- `rejection_reason text null`

Allowed statuses: `DRAFT`, `SUBMITTED`, `APPROVED`, `REJECTED`.

Rules:

- request belongs to one business;
- destination belongs to same business;
- requester identity is derived from current authority;
- DRAFT may be edited only by authorized requester/Owner;
- after SUBMITTED, destination and lines are frozen;
- APPROVED references exactly one Stock Transfer;
- REJECTED has rejection metadata and no transfer;
- APPROVED and REJECTED are terminal.

### 5.2 `public.restock_request_lines`

Fields:

- `id uuid primary key`
- `request_id uuid not null`
- `line_no integer not null`
- `stock_item_id uuid not null`
- `requested_quantity numeric(18,3) not null`
- `created_at timestamptz not null`

Constraints:

- quantity > 0 and ledger-compatible;
- same item appears only once per request;
- item is active and belongs to same business;
- deterministic `line_no` ordering;
- immutable after parent SUBMITTED.

## 6. Stock Transfer Data Model

### 6.1 `public.stock_transfers`

Fields:

- `id uuid primary key`
- `business_id uuid not null`
- `source_location_id uuid not null`
- `destination_location_id uuid not null`
- `status text not null default 'DRAFT'`
- `restock_request_id uuid null`
- `outbound_movement_id uuid null`
- `inbound_movement_id uuid null`
- `created_by uuid not null`
- `created_at timestamptz not null`
- `updated_at timestamptz not null`
- `shipped_by uuid null`
- `shipped_at timestamptz null`
- `received_by uuid null`
- `received_at timestamptz null`

Allowed statuses: `DRAFT`, `SHIPPED`, `RECEIVED`.

Rules:

- source and destination differ;
- both locations are active and belong to current business;
- direct transfer may have `restock_request_id is null`;
- one Restock Request links to at most one Stock Transfer;
- SHIPPED requires outbound movement metadata;
- RECEIVED requires outbound and inbound movement metadata;
- movement IDs cannot be reused by another transfer.

### 6.2 `public.stock_transfer_lines`

Fields:

- `id uuid primary key`
- `transfer_id uuid not null`
- `line_no integer not null`
- `stock_item_id uuid not null`
- `quantity numeric(18,3) not null`
- `created_at timestamptz not null`

Constraints:

- quantity > 0 and ledger-compatible;
- same item only once per transfer;
- item active and same-business at creation;
- deterministic order;
- immutable after SHIPPED.

## 7. Location Scope Authority

P7 introduces `public.inventory_location_scopes` with:

- `business_id uuid not null`
- `profile_id uuid not null`
- `location_id uuid not null`
- `active boolean not null default true`
- `created_at timestamptz not null`
- `created_by uuid not null`
- `updated_at timestamptz not null`
- `updated_by uuid not null`

Unique identity: `(business_id, profile_id, location_id)`.

Permission answers **what** the user may do; location scope answers **where**.

- Owner may act on all active locations in current business without explicit scope rows.
- Non-Owner + `INVENTORY_REQUEST` + destination scope may create/submit request for that destination.
- Non-Owner + `INVENTORY_TRANSFER` + source scope may ship from that source.
- Non-Owner + `INVENTORY_TRANSFER` + destination scope may receive into that destination.

### 7.1 Owner-managed scope assignment

Scope assignment is an application-managed authority, not a manual database task.

RPC:

`public.set_inventory_location_scope(p_profile_id uuid, p_location_id uuid, p_allowed boolean) -> jsonb`

Rules:

- Owner-only;
- target profile must be an active member of the current business;
- target location must be active and belong to the current business;
- `p_allowed = true` activates or creates the scope;
- `p_allowed = false` soft-disables the scope;
- scope rows are not hard-deleted;
- creator/updater actor and timestamps remain recorded;
- non-Owner callers are denied server-side.

## 8. Restock Request Commands

### 8.1 Save draft

`public.save_restock_request(p_request_id uuid, p_destination_location_id uuid, p_lines jsonb, p_notes text, p_idempotency_key text) -> jsonb`

Rules: resolve authority, require `INVENTORY_REQUEST` for non-Owner, enforce destination scope, validate active same-business location/items and quantities, create/replace only a DRAFT owned by requester, use canonical idempotency, and never rely on direct DML.

### 8.2 Submit

`public.submit_restock_request(p_request_id uuid) -> jsonb`

Rules: requester or Owner only; DRAFT only; at least one line; transition DRAFT → SUBMITTED; freeze request content.

### 8.3 Approve

`public.approve_restock_request(p_request_id uuid, p_source_location_id uuid, p_idempotency_key text) -> jsonb`

Rules:

1. require `INVENTORY_TRANSFER`;
2. request must be SUBMITTED;
3. source active, same-business, and different from destination;
4. approver chooses source location;
5. non-Owner needs source scope;
6. one transaction atomically creates exactly one DRAFT Stock Transfer, copies frozen lines, links request↔transfer, changes SUBMITTED→APPROVED, and stores actor/time;
7. retry returns the same transfer;
8. no inventory movement occurs during approval.

### 8.4 Reject

`public.reject_restock_request(p_request_id uuid, p_reason text) -> jsonb`

Requires `INVENTORY_TRANSFER`; request must be SUBMITTED; non-empty reason; transitions to REJECTED; no inventory movement; terminal immutable fact.

## 9. Direct Transfer Creation

`public.create_stock_transfer(p_source_location_id uuid, p_destination_location_id uuid, p_lines jsonb, p_idempotency_key text) -> jsonb`

Requires `INVENTORY_TRANSFER`; source scope for non-Owner; source != destination; active same-business locations/items; positive quantities; creates DRAFT only; no stock movement; idempotent.

## 10. Shipping Contract

`public.ship_stock_transfer(p_transfer_id uuid) -> jsonb`

Preconditions: valid authority, `INVENTORY_TRANSFER`, source scope for non-Owner, same-business transfer, DRAFT status, active source/destination, at least one line.

Concurrency sequence:

1. lock transfer row;
2. lock all involved `stock_items` rows in deterministic UUID order;
3. re-read current source ledger quantity after locks;
4. ensure every item has enough stock;
5. reject entire shipment if any line is insufficient.

No partial movement is allowed.

Inventory movement uses `private.record_inventory_movement(...)` exactly once with:

- idempotency key `TRANSFER_SHIP:<transfer_id>`;
- `movement_type = 'TRANSFER_OUT'`;
- `source_type = 'STOCK_TRANSFER'`;
- `source_ref = transfer_id::text`;
- `reason_code = 'TRANSFER_SHIPPED'`.

Each transfer line becomes one negative movement line at `source_location_id` in deterministic line order.

After success: `DRAFT → SHIPPED`, storing outbound movement, ship actor, and ship time. Lines become immutable.

## 11. In-Transit Semantics

P7 does not create a virtual inventory location.

While SHIPPED:

```text
source available stock      = already reduced
destination available stock = not yet increased
in-transit quantity         = frozen transfer-line quantity
```

In-transit is a projection from open SHIPPED transfers, not a separate inventory balance authority.

## 12. Receipt Contract

`public.receive_stock_transfer(p_transfer_id uuid) -> jsonb`

Requires valid authority, `INVENTORY_TRANSFER`, destination scope for non-Owner, same-business transfer, and SHIPPED status.

Inventory movement uses `private.record_inventory_movement(...)` exactly once with:

- idempotency key `TRANSFER_RECEIVE:<transfer_id>`;
- `movement_type = 'TRANSFER_IN'`;
- `source_type = 'STOCK_TRANSFER'`;
- `source_ref = transfer_id::text`;
- `reason_code = 'TRANSFER_RECEIVED'`.

Each frozen transfer line becomes one positive movement line at `destination_location_id`.

After success: `SHIPPED → RECEIVED`, storing inbound movement, receive actor, and receive time. RECEIVED becomes immutable.

## 13. Idempotency

- Draft save: same key + same payload returns same logical request; conflicting payload is rejected.
- Approval: one request creates at most one transfer; repeated approval returns linked transfer, never a duplicate.
- Direct transfer creation: same key + same payload returns same transfer.
- Ship retry: `TRANSFER_SHIP:<transfer_id>`; no duplicate outbound movement.
- Receive retry: `TRANSFER_RECEIVE:<transfer_id>`; no duplicate inbound movement.

## 14. Immutability

Direct DML for `anon` and `authenticated` is revoked on P7 authority tables.

Request rules:

- after SUBMITTED, destination/lines/requester immutable;
- APPROVED/REJECTED business facts immutable.

Transfer rules:

- after SHIPPED, source/destination/lines/creator/outbound movement immutable;
- after RECEIVED, entire transfer business fact immutable.

P7 does not implement reversal/correction. Future reversal must create compensating ledger facts, not edit historical facts.

## 15. Security

Every state-changing RPC is `SECURITY DEFINER`, uses `set search_path = ''`, fully schema-qualifies internal references, exposes only narrow RPC grants, and re-evaluates current authority, permission, business ownership, and resource scope.

Cross-tenant references fail closed. Caller cannot override business ID, requester/approver/ship/receive actor, movement IDs, or timestamps.

## 16. Stable Domain Errors

Restock errors:

- `RESTOCK_REQUEST_INVALID`
- `RESTOCK_PERMISSION_DENIED`
- `RESTOCK_SCOPE_DENIED`
- `RESTOCK_REQUEST_NOT_FOUND`
- `RESTOCK_REQUEST_NOT_DRAFT`
- `RESTOCK_REQUEST_NOT_SUBMITTED`
- `RESTOCK_REQUEST_ALREADY_RESOLVED`
- `RESTOCK_REQUEST_EMPTY`
- `RESTOCK_REJECTION_REASON_REQUIRED`
- `RESTOCK_IMMUTABLE`

Transfer errors:

- `TRANSFER_PERMISSION_DENIED`
- `TRANSFER_SCOPE_DENIED`
- `TRANSFER_LOCATION_INVALID`
- `TRANSFER_SAME_LOCATION`
- `TRANSFER_ITEM_INVALID`
- `TRANSFER_QUANTITY_INVALID`
- `TRANSFER_NOT_FOUND`
- `TRANSFER_NOT_DRAFT`
- `TRANSFER_NOT_SHIPPED`
- `TRANSFER_ALREADY_RECEIVED`
- `TRANSFER_STOCK_INSUFFICIENT`
- `TRANSFER_IMMUTABLE`

Existing canonical authority/idempotency errors remain authoritative where applicable.

## 17. SQL Regression Acceptance

Rollback-safe SQL integration must prove at least:

1. authorized requester + destination scope can save DRAFT;
2. requester can submit own request;
3. requester without `INVENTORY_TRANSFER` cannot approve/ship/receive;
4. Owner can approve SUBMITTED request;
5. approval creates exactly one linked DRAFT transfer;
6. repeated approval creates no second transfer;
7. direct Owner transfer without request works;
8. DRAFT/SUBMITTED/APPROVED request states create no inventory movement;
9. DRAFT transfer creates no inventory movement;
10. SHIPPED creates exactly one TRANSFER_OUT and reduces source only;
11. destination does not increase while SHIPPED;
12. RECEIVED creates exactly one TRANSFER_IN and increases destination;
13. ship/receive retry creates no duplicate movement;
14. source=destination rejected;
15. cross-tenant location/item rejected;
16. insufficient source stock rejects entire ship and leaves balances unchanged;
17. user without source scope cannot ship;
18. user without destination scope cannot receive;
19. transfer lines immutable after SHIPPED;
20. transfer fact immutable after RECEIVED;
21. submitted request lines immutable;
22. existing Purchase/GRN, BOM, and Production regressions remain clear.

Test runs inside `begin; ... rollback;`.

## 18. Source-Level Regression Acceptance

Source guards must assert:

- all five P7 tables exist;
- `INVENTORY_REQUEST` is seeded;
- existing `INVENTORY_TRANSFER` is reused;
- no second transfer permission system is created;
- location scope table exists;
- Restock Request and Stock Transfer remain separate state machines;
- request save/submit/approve/reject never call inventory writer;
- ship and receive call `private.record_inventory_movement(...)`;
- ship uses source location; receive uses destination location;
- stock insufficiency guard and deterministic locking exist;
- immutability guards exist;
- no partial shipment/receipt is introduced;
- direct authenticated DML is not granted;
- hardened `search_path = ''` exists;
- migration/test filenames are present in exact-history tests.

## 19. Mandatory Anti-Repeat Preflight

P7 must not be delivered as XP WORK until all local preflight gates pass.

### 19.1 TDD

- source guard begins RED because P7 implementation is missing;
- focused P7 turns GREEN after implementation;
- full Python regression GREEN.

### 19.2 Format gate

The exact package source must pass repository formatting. Design and plan Markdown must be Prettier-stable; supported ignore-range comments may be used where required. No known format failure may be shipped.

### 19.3 XP SQL classifier gate

Migration must classify as `DATA_CHANGE` under XP+ 2.1.0 classifier behavior.

Raw migration must avoid destructive/non-transactional classifier patterns including:

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

### 19.4 Compatibility regression

Focused compatibility covers P4R1 Goods Receipt hardening, P5 BOM Foundation, P6 Production Execution, and P7 Restock/Transfer.

### 19.5 Exact package replay

Before delivery:

1. apply XP operations to an isolated copy of latest locked source;
2. run focused P7 tests;
3. run compatibility regression;
4. run full Python tests;
5. validate SQL classifier;
6. validate JSON spec;
7. validate every operation path against `allowed_paths`;
8. confirm no unrelated path changes.

### 19.6 Database honesty

Local static tests are not live DB proof. Live migration and SQL regression count as successful only when XP runs them against configured PostgreSQL and reaches HUMAN_QA.

## 20. Human QA

Until full UI exists, SQL regression is primary transactional evidence. Human QA confirms authorized request behavior, unauthorized approval/ship/receive rejection, exactly one transfer per approval, source decrease at ship, destination increase only at receive, no duplicate stock on retries, shortage rejection, location-scope enforcement, immutability, and P4R1/P5/P6 regression clarity.

## 21. Explicitly Out of Scope

P7 does not implement:

- partial shipment or partial receipt;
- cancellation after SHIPPED;
- receipt discrepancy;
- damaged/lost-in-transit workflow;
- inventory write-off;
- min-stock recommendation engine;
- auto-restock;
- production-return automation;
- stock opname;
- inventory correction/reversal;
- full inventory UI;
- notification UI;
- transfer printing/reporting;
- Excel export.

These require later milestones or the CS-06 gap-audit decision.

## 22. Completion Gate

P7 completes only after source verification CLEAR, migration classification `DATA_CHANGE`, DB approval, migration success, SQL regression CLEAR, Human QA CLEAR, Final Lock, remote safepoint CLEAR, and terminal state:

`CS-06-P7-RESTOCK-TRANSFER — LOCKED_REMOTE (100%)`

No merge to `main` and no production deployment are part of P7.

After P7 locks, run a focused CS-06 gap audit against Inventory/Gudang/Gerai/Purchase/Supplier/Production blueprint before deciding whether another implementation milestone is required or CS-06 may close.

<!-- prettier-ignore-end -->
