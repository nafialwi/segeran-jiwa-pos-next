# CS-06-P7 Restock Request & Stock Transfer Implementation Plan

<!-- prettier-ignore-start -->

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add canonical Restock Request and Stock Transfer backend authorities with permission/location scope, full ship/receive semantics, idempotent stock movements, and no partial fulfillment.

**Architecture:** P7 keeps request approval separate from physical stock movement. Restock Requests move through DRAFT → SUBMITTED → APPROVED/REJECTED without inventory effects; approved requests create exactly one DRAFT Stock Transfer. Transfers move DRAFT → SHIPPED → RECEIVED, writing one canonical `TRANSFER_OUT` movement at ship and one canonical `TRANSFER_IN` movement at receipt. Non-Owner authority combines existing permission checks with explicit location scope.

**Tech Stack:** PostgreSQL/Supabase migrations, PL/pgSQL, CS-02 canonical inventory/idempotency authority, CS-03 permission/session authority, Python `unittest`, SQL rollback regressions, XP+ 2.1.0.

**Spec:** `docs/superpowers/specs/2026-09-16-cs-06-p7-restock-transfer-design.md`

## Global Constraints

- Previous gate: `CS-06-P6-PRODUCTION-EXECUTION — LOCKED_REMOTE`.
- Restock Request and Stock Transfer are separate authorities.
- Reuse existing `INVENTORY_TRANSFER`; add only `INVENTORY_REQUEST`.
- Owner may act across current-business locations; non-Owner actions require permission plus location scope.
- Owner-only location-scope management uses `set_inventory_location_scope(profile_id, location_id, allowed)` and soft enable/disable, never hard deletion.
- Source is selected at request approval time.
- No stock movement before transfer SHIPPED.
- SHIPPED writes exactly one source-negative canonical movement; RECEIVED writes exactly one destination-positive canonical movement.
- No virtual TRANSIT location; in-transit is a projection from SHIPPED transfers.
- No partial shipment or partial receipt in P7.
- Stock shortage rejects the entire shipment atomically.
- Submitted request content is immutable; shipped transfer lines are immutable; received transfer facts are immutable.
- Migration must classify as `DATA_CHANGE` under XP+ 2.1.0.
- Raw migration must avoid `DELETE FROM`, destructive DDL, and non-transactional classifier patterns.
- No main/master merge and no production deployment.

---

## File Structure

Create:
- `docs/superpowers/specs/2026-09-16-cs-06-p7-restock-transfer-design.md`
- `docs/superpowers/plans/2026-09-16-cs-06-p7-restock-transfer.md`
- `supabase/migrations/20260916143000_cs06_p7_restock_transfer.sql`
- `supabase/tests/cs06_p7_restock_transfer_test.sql`
- `tests/test_cs06_p7_restock_transfer.py`

Modify:
- `tests/test_cs02_migrations.py`

No other source path is in scope.

---

### Task 1 — Add RED source-contract and migration-history tests

**Files:**
- Create: `tests/test_cs06_p7_restock_transfer.py`
- Modify: `tests/test_cs02_migrations.py`

**Interfaces:**
- Consumes: P6 locked source tree and XP SQL-classifier behavior.
- Produces: executable source contract for the P7 migration and SQL regression.

- [ ] **Step 1: Create source-level contract tests before the migration exists.**

Require these contracts:
- five P7 tables: `restock_requests`, `restock_request_lines`, `stock_transfers`, `stock_transfer_lines`, `inventory_location_scopes`;
- permission seed `INVENTORY_REQUEST` while reusing `INVENTORY_TRANSFER`;
- scope soft-state `active boolean` and Owner-only `set_inventory_location_scope`;
- RPC names `save_restock_request`, `submit_restock_request`, `approve_restock_request`, `reject_restock_request`, `create_stock_transfer`, `ship_stock_transfer`, `receive_stock_transfer`;
- hardened SECURITY DEFINER/search path boundary;
- no canonical inventory writer call in request save/submit/approve/reject sections;
- exactly one outbound writer call and one inbound writer call in transfer posting sections;
- source stock guard and deterministic row locking;
- state/immutability trigger contracts;
- no partial shipment/receipt schema fields;
- XP classifier result `DATA_CHANGE` and no forbidden raw tokens.

- [ ] **Step 2: Register exact P7 migration/test filenames.**

Append exactly:
- `20260916143000_cs06_p7_restock_transfer.sql`
- `cs06_p7_restock_transfer_test.sql`

to the expected lists in `tests/test_cs02_migrations.py`.

- [ ] **Step 3: Run RED.**

Run:

```bash
python3 -m unittest tests.test_cs06_p7_restock_transfer tests.test_cs02_migrations -v
```

Expected: FAIL only because P7 migration and SQL regression files do not yet exist / exact history now expects them.

---

### Task 2 — Implement P7 schema, permission, and location-scope authority

**Files:**
- Create: `supabase/migrations/20260916143000_cs06_p7_restock_transfer.sql`

**Interfaces:**
- Consumes: `public.businesses`, `public.profiles`, `public.business_memberships`, `public.locations`, `public.stock_items`, `private.is_owner`, `private.has_permission`, `public.get_my_authority`.
- Produces: P7 authority tables, `INVENTORY_REQUEST`, active location scopes, Owner-only scope RPC.

- [ ] **Step 1: Seed `INVENTORY_REQUEST` idempotently.**

Use `insert ... on conflict (code) do update` only to keep the canonical label/category active; do not alter `INVENTORY_TRANSFER` semantics.

- [ ] **Step 2: Create `inventory_location_scopes`.**

Fields:

```text
business_id uuid
profile_id uuid
location_id uuid
active boolean default true
created_by uuid
created_at timestamptz
updated_by uuid
updated_at timestamptz
primary key (business_id, profile_id, location_id)
```

All referenced profiles/locations must belong to the same current business through RPC validation.

- [ ] **Step 3: Implement Owner-only scope mutation RPC.**

Signature:

```sql
public.set_inventory_location_scope(
  p_profile_id uuid,
  p_location_id uuid,
  p_allowed boolean
) returns jsonb
```

Behavior:
- resolve current authority;
- require `private.is_owner(v_business)`;
- validate active/current-business membership and location;
- `insert ... on conflict ... do update` active + updated actor/time;
- never hard-delete scope history;
- return profile/location/active state.

- [ ] **Step 4: Add read RLS and revoke direct client DML.**

Authenticated users may read current-business rows only; state changes are RPC-only.

---

### Task 3 — Implement Restock Request authority

**Files:**
- Create/continue: `supabase/migrations/20260916143000_cs06_p7_restock_transfer.sql`

**Interfaces:**
- Consumes: `INVENTORY_REQUEST`, location scope helper logic, CS-02 idempotency primitives.
- Produces: request tables, mutation guards, four request RPCs.

- [ ] **Step 1: Create request header/line tables and constraints.**

`restock_requests` statuses: `DRAFT`, `SUBMITTED`, `APPROVED`, `REJECTED`.

`restock_request_lines` stores deterministic `line_no`, `stock_item_id`, `requested_quantity numeric(18,3)`.

- [ ] **Step 2: Add mutation guards.**

Allow only:
- DRAFT content update;
- DRAFT → SUBMITTED;
- SUBMITTED → APPROVED;
- SUBMITTED → REJECTED.

After SUBMITTED, destination/requester/lines are immutable. APPROVED and REJECTED are terminal.

- [ ] **Step 3: Implement `save_restock_request`.**

Signature:

```sql
public.save_restock_request(
  p_request_id uuid,
  p_destination_location_id uuid,
  p_lines jsonb,
  p_notes text,
  p_idempotency_key text
) returns jsonb
```

Validate permission/scope, item tenant/activity, unique items, positive 3-decimal quantities. Reconcile DRAFT lines using classifier-safe `MERGE`, not raw `DELETE FROM`.

- [ ] **Step 4: Implement `submit_restock_request`.**

Require owner/requester authority, non-empty DRAFT, then atomically freeze DRAFT → SUBMITTED.

- [ ] **Step 5: Implement `approve_restock_request`.**

Signature:

```sql
public.approve_restock_request(
  p_request_id uuid,
  p_source_location_id uuid,
  p_idempotency_key text
) returns jsonb
```

Require `INVENTORY_TRANSFER`; non-Owner source scope; source differs from destination; lock request; create exactly one DRAFT transfer with copied lines; link both authorities; update SUBMITTED → APPROVED in one transaction; no inventory movement.

- [ ] **Step 6: Implement `reject_restock_request`.**

Require `INVENTORY_TRANSFER`, non-empty reason, SUBMITTED state; transition to REJECTED with actor/time; no inventory movement.

---

### Task 4 — Implement Stock Transfer authority and canonical ledger posting

**Files:**
- Continue: `supabase/migrations/20260916143000_cs06_p7_restock_transfer.sql`

**Interfaces:**
- Consumes: request authority, location scopes, `private.record_inventory_movement(...)`.
- Produces: transfer tables, direct-create RPC, ship RPC, receive RPC.

- [ ] **Step 1: Create transfer header/line tables.**

Statuses: `DRAFT`, `SHIPPED`, `RECEIVED`.

Header contains source/destination, optional request link, outbound/inbound movement IDs, actor/timestamps. Lines contain one unique item per transfer with positive 3-decimal quantity.

- [ ] **Step 2: Add transfer mutation guards.**

Allow only exact DRAFT → SHIPPED and SHIPPED → RECEIVED transitions. Lines become immutable after SHIPPED; RECEIVED is fully immutable.

- [ ] **Step 3: Implement direct `create_stock_transfer`.**

Signature:

```sql
public.create_stock_transfer(
  p_source_location_id uuid,
  p_destination_location_id uuid,
  p_lines jsonb,
  p_idempotency_key text
) returns jsonb
```

Require `INVENTORY_TRANSFER`, non-Owner source scope, valid same-business locations/items/quantities, DRAFT only, no stock movement.

- [ ] **Step 4: Implement `ship_stock_transfer`.**

Signature:

```sql
public.ship_stock_transfer(p_transfer_id uuid) returns jsonb
```

Behavior:
- lock transfer row;
- replay safely if outbound already exists;
- require DRAFT, source permission/scope;
- lock involved stock items in deterministic UUID order;
- re-read canonical source ledger balances after locks;
- reject all if any line is short;
- build negative movement lines at source;
- call `private.record_inventory_movement` exactly once with key `TRANSFER_SHIP:<id>`, type `TRANSFER_OUT`, source `STOCK_TRANSFER`, reason `TRANSFER_SHIPPED`;
- update DRAFT → SHIPPED with outbound movement/actor/time.

- [ ] **Step 5: Implement `receive_stock_transfer`.**

Signature:

```sql
public.receive_stock_transfer(p_transfer_id uuid) returns jsonb
```

Behavior:
- lock transfer row;
- replay safely if already RECEIVED;
- require SHIPPED and destination permission/scope;
- build positive movement lines from frozen transfer lines at destination;
- call canonical writer exactly once with key `TRANSFER_RECEIVE:<id>`, type `TRANSFER_IN`, source `STOCK_TRANSFER`, reason `TRANSFER_RECEIVED`;
- update SHIPPED → RECEIVED with inbound movement/actor/time.

---

### Task 5 — Add rollback-safe SQL integration regression

**Files:**
- Create: `supabase/tests/cs06_p7_restock_transfer_test.sql`

**Interfaces:**
- Consumes: P7 RPCs plus existing auth/session fixtures and canonical inventory writer.
- Produces: live-DB acceptance proof inside one rollback transaction.

- [ ] **Step 1: Build owner/requester/transfer-staff fixtures.**

Create deterministic auth/session/profile/device rows, grant `INVENTORY_REQUEST` to requester, grant `INVENTORY_TRANSFER` to transfer staff using per-user overrides, and use Owner scope RPC to grant/revoke explicit location scopes.

- [ ] **Step 2: Exercise request lifecycle.**

Prove save/submit; request-only actor cannot approve/ship/receive; Owner approval creates exactly one transfer; approval replay does not duplicate transfer; request states do not write inventory.

- [ ] **Step 3: Exercise transfer lifecycle.**

Seed source stock through canonical inventory writer; prove direct transfer; prove DRAFT no movement; ship source-only decrement; destination unchanged while SHIPPED; receive destination increment; ship/receive replay no duplicate movement.

- [ ] **Step 4: Exercise security and failure atomicity.**

Prove same-location/cross-tenant rejection, source-scope and destination-scope denial, scope revoke effect, insufficient stock full rollback, and immutable submitted/shipped/received facts.

- [ ] **Step 5: Wrap the test.**

File must begin `begin;` and end `rollback;`.

---

### Task 6 — GREEN, compatibility regression, and anti-repeat preflight

**Files:**
- All P7 files plus existing regression suite.

- [ ] **Step 1: Run focused GREEN.**

```bash
python3 -m unittest tests.test_cs06_p7_restock_transfer tests.test_cs06_p6_production_execution tests.test_cs06_p5_bom_foundation tests.test_cs06_p4r1_grn_hardening tests.test_cs02_migrations -v
```

Expected: all PASS.

- [ ] **Step 2: Run full Python suite.**

```bash
python3 -m unittest discover -s tests -p 'test_*.py' -v
```

Expected: zero failures/errors.

- [ ] **Step 3: Run XP SQL classifier simulation.**

Expected exact class: `DATA_CHANGE`.

Forbidden raw patterns must be absent.

- [ ] **Step 4: Run format preflight without network installation.**

Use repository-local Prettier only if available (`npx --no-install prettier --check ...`). If unavailable locally, do not claim Prettier passed; keep both Markdown files inside supported ignore ranges and leave final format authority to XP.

---

### Task 7 — Build and replay exact XP WORK spec

**Files:**
- Create delivery artifact: `CS06_P7_RESTOCK_TRANSFER_spec.json`

**Interfaces:**
- Consumes: exact final contents of six scoped project files.
- Produces: XP declarative WORK package input.

- [ ] **Step 1: Build WORK spec with only these allowed paths.**

```text
docs/superpowers/specs/2026-09-16-cs-06-p7-restock-transfer-design.md
docs/superpowers/plans/2026-09-16-cs-06-p7-restock-transfer.md
supabase/migrations/20260916143000_cs06_p7_restock_transfer.sql
supabase/tests/cs06_p7_restock_transfer_test.sql
tests/test_cs06_p7_restock_transfer.py
tests/test_cs02_migrations.py
```

Use `ADD_FILE` for new files, `REPLACE_FILE` for migration-history test, `APPLY_DB_MIGRATION` for migration, and `RUN_SQL_TEST` for SQL regression according to XP schema.

- [ ] **Step 2: Replay exact operations into a fresh isolated P6-locked copy.**

Verify no out-of-scope paths change.

- [ ] **Step 3: Re-run focused/full tests and classifier against replay.**

Only after fresh replay evidence is green may the spec be delivered to the user.

---

## Completion Evidence Required Before Delivery

P7 package may be handed to XP only when fresh evidence shows:

- RED observed before implementation;
- focused GREEN;
- full Python GREEN;
- compatibility P4R1/P5/P6 GREEN;
- exact migration history GREEN;
- classifier `DATA_CHANGE`;
- forbidden classifier tokens absent;
- exact WORK-spec replay GREEN;
- JSON valid;
- allowed-path scope exact.

Live database completion is **not** claimed locally. Final authority remains XP migration + SQL regression + HUMAN_QA + Final Lock.

<!-- prettier-ignore-end -->
