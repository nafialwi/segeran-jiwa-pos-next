# CS-06-P5 BOM Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a versioned, tenant-safe, permission-gated BOM recipe authority for finished goods without changing inventory stock.

**Architecture:** P5 adds `boms` and `bom_lines` plus two narrow SECURITY DEFINER RPCs: `save_bom_draft(...)` and `activate_bom(...)`. All write authorization is enforced with `PRODUCTION_MANAGE`; `stock_items` remains the canonical item authority, BOM component quantities are base-unit numeric(18,3), and no P5 code may call the inventory ledger writer.

**Tech Stack:** PostgreSQL/Supabase SQL migrations, PL/pgSQL, existing CS-02 idempotency primitives, CS-03 permission/session authority, Python `unittest`, XP+ 2.1.0 package workflow.

**Spec:** `docs/superpowers/specs/2026-09-15-cs-06-p5-bom-foundation-design.md`

## Global Constraints

- Blueprint baseline: `v1.0 FINAL LOCK`.
- Source baseline entering P5: `ecad4bcb31a779d943dce20777862a12115be51c`.
- Previous locked milestone: `CS-06-P4R1-GRN-HARDENING`.
- `stock_items` is the canonical item master.
- BOM header target must be an active `FINISHED_GOOD`.
- BOM component kinds allowed in P5: `MATERIAL`, `PACKAGING`, `OTHER`.
- BOM component quantities are canonical base-unit quantities with maximum three decimal places.
- State-changing BOM RPCs require `PRODUCTION_MANAGE`.
- SECURITY DEFINER functions use `set search_path = ''` and schema-qualified references.
- `anon` and `authenticated` receive no direct INSERT/UPDATE/DELETE authority on BOM tables.
- P5 must not call `private.record_inventory_movement(...)`.
- P5 must not modify locked CS-06 P1–P4R1 migrations.
- Production execution, stock consumption/output, costing, waste, reversal, and production UI are out of P5.
- Source mutation is applied only through XP+ WORK package workflow on the current `work/*` branch.
- P5 acceptance requires SQL regression CLEAR, canonical verify CLEAR, Human QA CLEAR, and final `LOCKED_REMOTE`.

---

## File Structure

### New files

- `docs/superpowers/specs/2026-09-15-cs-06-p5-bom-foundation-design.md`  
  Approved design authority for P5.

- `docs/superpowers/plans/2026-09-15-cs-06-p5-bom-foundation.md`  
  This implementation plan.

- `supabase/migrations/20260915223000_cs06_p5_bom_foundation.sql`  
  BOM tables, indexes, RLS, immutability guards, RPCs, grants/comments.

- `supabase/tests/cs06_p5_bom_foundation_test.sql`  
  Transactional integration/regression test using real authority, permissions, and idempotency flow.

- `tests/test_cs06_p5_bom_foundation.py`  
  Source-level contract guard.

### Modified file

- `tests/test_cs02_migrations.py`  
  Append the P5 migration and SQL test to exact-history lists.

No other files are in scope for P5.

---

### Task 1: Commit the approved P5 design and implementation plan as source-controlled authority

**Files:**
- Create: `docs/superpowers/specs/2026-09-15-cs-06-p5-bom-foundation-design.md`
- Create: `docs/superpowers/plans/2026-09-15-cs-06-p5-bom-foundation.md`

**Interfaces:**
- Consumes: approved chat design for `CS-06-P5-BOM-FOUNDATION`.
- Produces: immutable implementation authority referenced by later tasks.

- [ ] **Step 1: Add the approved design document**

Use the exact approved design text whose core contracts are:

```text
BOM lifecycle: DRAFT -> ACTIVE -> RETIRED
One ACTIVE BOM per (business_id, finished_good_id)
Write permission: PRODUCTION_MANAGE
Canonical item master: stock_items
Canonical recipe quantity: base-unit numeric(18,3)
P5 inventory side effects: forbidden
```

- [ ] **Step 2: Add this implementation plan**

Save this plan verbatim at:

```text
docs/superpowers/plans/2026-09-15-cs-06-p5-bom-foundation.md
```

- [ ] **Step 3: Verify both authority documents exist**

Run:

```bash
test -s docs/superpowers/specs/2026-09-15-cs-06-p5-bom-foundation-design.md
test -s docs/superpowers/plans/2026-09-15-cs-06-p5-bom-foundation.md
```

Expected: both commands exit `0`.

---

### Task 2: Add RED source-level contract guards

**Files:**
- Create: `tests/test_cs06_p5_bom_foundation.py`
- Modify: `tests/test_cs02_migrations.py`

**Interfaces:**
- Consumes: exact P5 migration/test paths.
- Produces: source-level checks that fail before migration/test implementation exists.

- [ ] **Step 1: Create the P5 source guard test**

Create `tests/test_cs06_p5_bom_foundation.py` with:

```python
from __future__ import annotations

import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MIGRATION = ROOT / "supabase" / "migrations" / "20260915223000_cs06_p5_bom_foundation.sql"
SQL_TEST = ROOT / "supabase" / "tests" / "cs06_p5_bom_foundation_test.sql"


class Cs06P5BomFoundationTests(unittest.TestCase):
    def _migration(self) -> str:
        self.assertTrue(MIGRATION.is_file(), "P5 BOM migration must exist")
        return MIGRATION.read_text(encoding="utf-8").lower()

    def _sql_test(self) -> str:
        self.assertTrue(SQL_TEST.is_file(), "P5 BOM SQL integration test must exist")
        return SQL_TEST.read_text(encoding="utf-8").lower()

    def test_bom_schema_and_single_active_constraint_exist(self) -> None:
        source = self._migration()
        for token in (
            "create table public.boms",
            "create table public.bom_lines",
            "status in ('draft', 'active', 'retired')",
            "unique (business_id, finished_good_id, version)",
            "where status = 'active'",
        ):
            self.assertIn(token, source)

    def test_write_boundary_requires_production_permission(self) -> None:
        source = self._migration()
        self.assertGreaterEqual(
            source.count("private.has_permission(v_business, 'production_manage')"),
            2,
        )
        self.assertIn("sj_production_permission_denied", source)

    def test_security_definer_functions_use_hardened_search_path(self) -> None:
        source = self._migration()
        self.assertGreaterEqual(source.count("security definer"), 2)
        self.assertGreaterEqual(source.count("set search_path = ''"), 2)

    def test_stock_items_are_canonical_and_products_are_not_used(self) -> None:
        source = self._migration()
        self.assertIn("public.stock_items", source)
        self.assertNotIn("public.products", source)

    def test_p5_does_not_write_inventory(self) -> None:
        source = self._migration()
        self.assertNotIn("private.record_inventory_movement(", source)
        self.assertNotIn("insert into public.inventory_movements", source)
        self.assertNotIn("insert into public.inventory_movement_lines", source)

    def test_rpc_contracts_and_idempotency_are_present(self) -> None:
        source = self._migration()
        for token in (
            "public.save_bom_draft(",
            "public.activate_bom(",
            "private.lock_operation(",
            "private.record_operation_success(",
            "bom_duplicate_component",
            "bom_self_reference",
            "bom_ledger_precision_unsupported",
            "bom_not_draft",
        ):
            self.assertIn(token, source)

    def test_direct_client_dml_is_not_granted(self) -> None:
        source = self._migration()
        self.assertIn("revoke all on table public.boms", source)
        self.assertIn("revoke all on table public.bom_lines", source)
        self.assertNotIn("grant insert", source)
        self.assertNotIn("grant update", source)
        self.assertNotIn("grant delete", source)

    def test_sql_integration_test_covers_real_bom_flow(self) -> None:
        source = self._sql_test()
        self.assertTrue(source.lstrip().startswith("begin;"))
        self.assertTrue(source.rstrip().endswith("rollback;"))
        for token in (
            "public.save_bom_draft(",
            "public.activate_bom(",
            "production_manage",
            "bom_self_reference",
            "bom_duplicate_component",
            "sj_production_permission_denied",
            "inventory_movements",
            "inventory_balances",
            "status = 'retired'",
        ):
            self.assertIn(token, source)


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Register the future migration/test names in the exact-history lists**

Append to `EXPECTED_MIGRATIONS` in `tests/test_cs02_migrations.py`:

```python
"20260915223000_cs06_p5_bom_foundation.sql",
```

Append to `EXPECTED_SQL_TESTS`:

```python
"cs06_p5_bom_foundation_test.sql",
```

- [ ] **Step 3: Run the RED source tests**

Run:

```bash
python3 -m unittest tests.test_cs06_p5_bom_foundation -v
```

Expected: FAIL because the P5 migration and SQL test do not exist yet.

Run:

```bash
python3 -m unittest tests.test_cs02_migrations -v
```

Expected: FAIL because exact migration/test history now expects P5 files.

Do not continue until failures are specifically caused by missing P5 files.

---

### Task 3: Implement the P5 BOM migration

**Files:**
- Create: `supabase/migrations/20260915223000_cs06_p5_bom_foundation.sql`
- Test: `tests/test_cs06_p5_bom_foundation.py`

**Interfaces:**
- Consumes:
  - `public.stock_items(id, business_id, item_kind, active, base_unit_id)`
  - `public.get_my_authority() -> jsonb`
  - `private.has_permission(uuid, text) -> boolean`
  - `private.lock_operation(uuid, text, text, text)`
  - `private.record_operation_success(...) -> uuid`
  - `private.payload_sha256(jsonb) -> text`
- Produces:
  - `public.boms`
  - `public.bom_lines`
  - `public.save_bom_draft(uuid, integer, numeric, jsonb, text) -> jsonb`
  - `public.activate_bom(uuid, text) -> jsonb`

- [ ] **Step 1: Add BOM tables and constraints**

Implement:

```sql
create table public.boms (
    id uuid primary key default gen_random_uuid(),
    business_id uuid not null references public.businesses(id) on delete restrict,
    finished_good_id uuid not null references public.stock_items(id) on delete restrict,
    version integer not null,
    status text not null default 'DRAFT',
    yield_quantity numeric(18,3) not null,
    created_by uuid not null references public.profiles(id) on delete restrict,
    created_at timestamptz not null default now(),
    activated_by uuid references public.profiles(id) on delete restrict,
    activated_at timestamptz,
    retired_by uuid references public.profiles(id) on delete restrict,
    retired_at timestamptz,
    updated_at timestamptz not null default now(),
    unique (business_id, finished_good_id, version),
    constraint boms_version_positive check (version > 0),
    constraint boms_yield_positive check (yield_quantity > 0),
    constraint boms_status_valid check (status in ('DRAFT', 'ACTIVE', 'RETIRED'))
);

create unique index boms_one_active_per_finished_good_idx
on public.boms(business_id, finished_good_id)
where status = 'ACTIVE';

create table public.bom_lines (
    bom_id uuid not null references public.boms(id) on delete cascade,
    line_no integer not null,
    component_stock_item_id uuid not null references public.stock_items(id) on delete restrict,
    base_quantity numeric(18,3) not null,
    created_at timestamptz not null default now(),
    primary key (bom_id, line_no),
    unique (bom_id, component_stock_item_id),
    constraint bom_lines_line_no_positive check (line_no > 0),
    constraint bom_lines_base_quantity_positive check (base_quantity > 0)
);
```

Add indexes on `boms.business_id`, `boms.finished_good_id`, `boms.status`, and `bom_lines.component_stock_item_id`.

- [ ] **Step 2: Add tenant-aware RLS read policies and direct-DML revokes**

Implement RLS policies that compare the BOM business to:

```sql
(public.get_my_authority() ->> 'business_id')::uuid
```

Then explicitly revoke direct privileges:

```sql
revoke all on table public.boms
from public, anon, authenticated;

revoke all on table public.bom_lines
from public, anon, authenticated;

grant select on table public.boms to authenticated;
grant select on table public.bom_lines to authenticated;
```

RLS remains the read isolation boundary; write RPCs bypass row policies only after their own authority checks.

- [ ] **Step 3: Add immutable-history trigger for ACTIVE/RETIRED BOMs**

Create a private trigger function that allows DRAFT edits but rejects UPDATE/DELETE when `old.status in ('ACTIVE','RETIRED')` unless the only transition is the controlled ACTIVE -> RETIRED transition performed by `activate_bom`.

The exact permitted state transition is:

```text
DRAFT -> ACTIVE
ACTIVE -> RETIRED
DRAFT -> DRAFT
```

Forbidden transitions include:

```text
ACTIVE -> ACTIVE content mutation
RETIRED -> any mutation
ACTIVE/RETIRED line INSERT/UPDATE/DELETE
```

Use stable domain error:

```text
BOM_IMMUTABLE
```

- [ ] **Step 4: Implement `save_bom_draft(...)`**

Use this exact signature:

```sql
create or replace function public.save_bom_draft(
    p_finished_good_id uuid,
    p_version integer,
    p_yield_quantity numeric,
    p_lines jsonb,
    p_idempotency_key text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
```

The function must:

```text
1. Read business_id/profile_id from public.get_my_authority().
2. Fail SJ_AUTHORITY_DENIED if either is missing.
3. Require private.has_permission(v_business, 'PRODUCTION_MANAGE').
4. Validate p_version > 0.
5. Validate p_yield_quantity > 0 and equal to round(value, 3).
6. Validate p_lines is a non-empty JSON array.
7. Validate finished good is same-business, active, FINISHED_GOOD.
8. Validate every line has component_stock_item_id and base_quantity.
9. Reject duplicate component ids.
10. Reject component == finished_good_id.
11. Require each component same-business, active, kind in MATERIAL/PACKAGING/OTHER.
12. Require each quantity > 0 and equal to round(quantity, 3).
13. Build deterministic payload JSON and SHA256.
14. Call private.lock_operation(..., 'BOM_SAVE_DRAFT', payload_hash).
15. On replay, return the existing BOM id with replay=true.
16. Advisory-lock the business/finished-good/version tuple.
17. If the version exists as ACTIVE/RETIRED, fail BOM_NOT_DRAFT.
18. Insert a new DRAFT or update existing DRAFT yield.
19. Replace DRAFT lines deterministically with line_no assigned from input order.
20. Record success with private.record_operation_success(... result_type='BOM').
21. Return {success:true,replay:false,bom_id,status:'DRAFT',version}.
```

Use these exact domain messages where applicable:

```text
SJ_PRODUCTION_PERMISSION_DENIED
BOM_FINISHED_GOOD_INVALID
BOM_VERSION_INVALID
BOM_YIELD_INVALID
BOM_LINES_REQUIRED
BOM_LINE_INVALID
BOM_DUPLICATE_COMPONENT
BOM_SELF_REFERENCE
BOM_LEDGER_PRECISION_UNSUPPORTED
BOM_NOT_DRAFT
```

- [ ] **Step 5: Implement `activate_bom(...)`**

Use this exact signature:

```sql
create or replace function public.activate_bom(
    p_bom_id uuid,
    p_idempotency_key text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
```

The function must:

```text
1. Resolve current authority and require PRODUCTION_MANAGE.
2. Lock the target BOM row by id/business.
3. Build payload {bom_id}.
4. Use private.lock_operation(..., 'BOM_ACTIVATE', payload_hash).
5. On replay, return existing BOM id with replay=true and current status.
6. Require target status DRAFT.
7. Require at least one line.
8. Revalidate finished good and all components.
9. Advisory-lock business/finished_good active slot.
10. Retire any different ACTIVE BOM for the same finished good.
11. Update target DRAFT -> ACTIVE, setting activated_by/activated_at.
12. Record success result_type='BOM'.
13. Return {success:true,replay:false,bom_id,status:'ACTIVE',version,retired_bom_id}.
```

Use:

```text
BOM_NOT_FOUND
BOM_NOT_DRAFT
BOM_LINES_REQUIRED
BOM_CROSS_TENANT
```

for relevant failures.

- [ ] **Step 6: Lock function privileges**

Use:

```sql
revoke execute on function public.save_bom_draft(uuid, integer, numeric, jsonb, text)
from public, anon, authenticated, service_role;

grant execute on function public.save_bom_draft(uuid, integer, numeric, jsonb, text)
to authenticated;

revoke execute on function public.activate_bom(uuid, text)
from public, anon, authenticated, service_role;

grant execute on function public.activate_bom(uuid, text)
to authenticated;
```

Add comments documenting that P5 defines recipes only and has no stock side effects.

- [ ] **Step 7: Run the P5 source guard**

Run:

```bash
python3 -m unittest tests.test_cs06_p5_bom_foundation -v
```

Expected: migration-oriented tests pass; SQL-test-oriented test still fails until Task 4 creates the integration test.

---

### Task 4: Add transactional SQL integration/regression coverage

**Files:**
- Create: `supabase/tests/cs06_p5_bom_foundation_test.sql`
- Test: `tests/test_cs06_p5_bom_foundation.py`
- Test: `tests/test_cs02_migrations.py`

**Interfaces:**
- Consumes: P5 tables/RPCs plus existing CS-03 session authority.
- Produces: executable DB evidence for authorization, lifecycle, idempotency, tenant safety, immutability, and no-stock-side-effects.

- [ ] **Step 1: Start a rollback-safe test**

The file must start with:

```sql
begin;
```

and end with:

```sql
rollback;
```

Create deterministic UUID fixtures for:

- one owner/authorized actor;
- one cashier/unauthorized actor;
- one second business for cross-tenant checks;
- one FINISHED_GOOD;
- two MATERIAL/PACKAGING components;
- one OTHER component;
- one invalid FINISHED_GOOD component candidate.

Reuse the same authenticated JWT/session pattern already used by `cs06_p4r1_grn_hardening_test.sql`.

- [ ] **Step 2: Prove authorized DRAFT save and idempotent replay**

As authorized actor, call:

```sql
select public.save_bom_draft(
    '<finished-good-uuid>',
    1,
    1.000,
    jsonb_build_array(
        jsonb_build_object('component_stock_item_id','<material-uuid>','base_quantity',0.250),
        jsonb_build_object('component_stock_item_id','<packaging-uuid>','base_quantity',1.000)
    ),
    'P5:BOM:SAVE:V1'
);
```

Assert:

```text
status = DRAFT
version = 1
exactly 2 bom_lines
same idempotency key replay returns same bom_id
replay does not create a second BOM
```

- [ ] **Step 3: Prove validation failures**

Use exception blocks that assert exact messages for:

```text
BOM_SELF_REFERENCE
BOM_DUPLICATE_COMPONENT
BOM_LEDGER_PRECISION_UNSUPPORTED
BOM_FINISHED_GOOD_INVALID
BOM_CROSS_TENANT or BOM_LINE_INVALID for a foreign-business component
```

Each test must fail the SQL script if the expected error is not raised.

- [ ] **Step 4: Prove unauthorized writes are rejected**

Switch to cashier JWT/session and assert both calls fail with:

```text
SJ_PRODUCTION_PERMISSION_DENIED
```

for:

```sql
public.save_bom_draft(...)
public.activate_bom(...)
```

- [ ] **Step 5: Prove activation lifecycle**

Switch back to the authorized actor.

Activate V1:

```sql
select public.activate_bom('<v1-bom-id>', 'P5:BOM:ACTIVATE:V1');
```

Assert V1 is `ACTIVE`.

Create V2 with a changed component quantity and activate V2.

Assert:

```text
V1 status = RETIRED
V2 status = ACTIVE
exactly one ACTIVE BOM exists for the finished good
```

Replay V2 activation with the same idempotency key and assert no additional state transition occurs.

- [ ] **Step 6: Prove immutable recipe history**

Attempt to modify an ACTIVE or RETIRED BOM header and line.

Assert:

```text
BOM_IMMUTABLE
```

- [ ] **Step 7: Prove BOM operations do not modify inventory**

Before BOM operations, capture counts/sums for:

```sql
public.inventory_movements
public.inventory_movement_lines
public.inventory_balances
```

After save/activate/version rollover, assert the captured inventory state is unchanged for the fixture item/location scope.

- [ ] **Step 8: Run source guards again**

Run:

```bash
python3 -m unittest tests.test_cs06_p5_bom_foundation -v
python3 -m unittest tests.test_cs02_migrations -v
```

Expected: PASS.

---

### Task 5: Run canonical verification and inspect the implementation boundary

**Files:**
- No new files.

**Interfaces:**
- Consumes: all P5 source changes.
- Produces: verified source tree ready to package through XP.

- [ ] **Step 1: Run focused Python regression**

Run:

```bash
python3 -m unittest \
  tests.test_cs06_p5_bom_foundation \
  tests.test_cs06_p4r1_grn_hardening \
  tests.test_cs02_migrations \
  -v
```

Expected: all tests PASS.

- [ ] **Step 2: Run the full canonical project verification**

Run:

```bash
npm run verify
```

Expected: exit `0`, with no new failure or warning beyond the repository's already-known warning policy.

- [ ] **Step 3: Inspect diff scope**

Run:

```bash
git diff -- \
  docs/superpowers/specs/2026-09-15-cs-06-p5-bom-foundation-design.md \
  docs/superpowers/plans/2026-09-15-cs-06-p5-bom-foundation.md \
  supabase/migrations/20260915223000_cs06_p5_bom_foundation.sql \
  supabase/tests/cs06_p5_bom_foundation_test.sql \
  tests/test_cs06_p5_bom_foundation.py \
  tests/test_cs02_migrations.py
```

Expected: only the six approved P5 paths are changed.

- [ ] **Step 4: Confirm forbidden inventory write tokens are absent**

Run:

```bash
grep -nE \
  "record_inventory_movement|insert into public\.inventory_movements|insert into public\.inventory_movement_lines" \
  supabase/migrations/20260915223000_cs06_p5_bom_foundation.sql
```

Expected: no output.

---

### Task 6: Build and execute the XP+ WORK package

**Files:**
- Package spec generated outside the repo:
  `CS06_P5_BOM_FOUNDATION_spec.json`

**Interfaces:**
- Consumes: six verified P5 source paths.
- Produces: XP+ WORK package and, after acceptance, a P5 `LOCKED_REMOTE` checkpoint.

- [ ] **Step 1: Build one declarative WORK spec**

Use:

```json
{
  "spec_version": "1.0",
  "package_type": "WORK",
  "project_id": "segeran-jiwa-pos-next",
  "milestone": "CS-06-P5-BOM-FOUNDATION",
  "allowed_paths": [
    "docs/superpowers/specs/2026-09-15-cs-06-p5-bom-foundation-design.md",
    "docs/superpowers/plans/2026-09-15-cs-06-p5-bom-foundation.md",
    "supabase/migrations/20260915223000_cs06_p5_bom_foundation.sql",
    "supabase/tests/cs06_p5_bom_foundation_test.sql",
    "tests/test_cs06_p5_bom_foundation.py",
    "tests/test_cs02_migrations.py"
  ]
}
```

The operation list must contain one operation for each allowed path:

```text
ADD_FILE design spec
ADD_FILE implementation plan
APPLY_DB_MIGRATION P5 migration
RUN_SQL_TEST P5 SQL regression
ADD_FILE P5 source guard
REPLACE_FILE migration-history test
```

The package `human_qa` checklist must include:

```text
Authorized actor can save a DRAFT BOM.
Unauthorized actor cannot save or activate.
Activation yields exactly one ACTIVE version.
Newer activation retires older ACTIVE version.
Invalid/self-referential/duplicate component input is rejected.
Idempotent retry is stable.
BOM save/activation does not alter inventory.
Re-query reproduces the same active BOM/version.
Purchase/GRN verification remains clear.
```

- [ ] **Step 2: Build package with XP**

Run:

```bash
xp pkg-build \
  --repo "$HOME/WORKSTATION/projects/segeran-jiwa-pos-next" \
  --spec "$HOME/storage/shared/Download/CS06_P5_BOM_FOUNDATION_spec.json"
```

Expected package:

```text
XP_PKG_WORK_segeran-jiwa-pos-next_CS-06-P5-BOM-FOUNDATION.zip
```

- [ ] **Step 3: Execute through XP safe gates**

From XP Home:

```text
[2] Scan hasil GPT terbaru
-> choose CS-06-P5-BOM-FOUNDATION compatible package
-> source verify
-> DB approval
-> DB apply
-> SQL regression
-> HUMAN_QA
```

If XP reports any failure, rollback, `WAITING_GPT`, or `XP_GPT_INCIDENT`, stop and preserve the incident artifact.

- [ ] **Step 4: Complete Human QA**

Select `QA CLEAR` only after the P5 checklist is satisfied.

- [ ] **Step 5: Final Lock**

Approve Final Lock only when XP shows the correct milestone:

```text
CS-06-P5-BOM-FOUNDATION
```

Expected terminal state:

```text
LOCKED_REMOTE (100%)
```

Checkpoint evidence must include source verification, DB applied/verified evidence, Human QA CLEAR, source archive, SHA256, and remote safepoint.

---

## Self-Review

### Spec coverage

Covered:

- versioned BOM header and lines;
- single ACTIVE recipe;
- DRAFT/ACTIVE/RETIRED lifecycle;
- immutable activated history;
- `PRODUCTION_MANAGE`;
- tenant validation;
- `stock_items` canonical authority;
- base-unit three-decimal quantity authority;
- idempotency;
- no inventory side effects;
- RLS/direct-DML boundary;
- SQL + source regression;
- Human QA and XP Final Lock.

### Placeholder scan

No `TBD`, `TODO`, “implement later”, or unspecified implementation steps remain.

### Type/signature consistency

Canonical RPC signatures used throughout the plan:

```text
save_bom_draft(uuid, integer, numeric, jsonb, text) -> jsonb
activate_bom(uuid, text) -> jsonb
```

Canonical P5 paths used consistently:

```text
20260915223000_cs06_p5_bom_foundation.sql
cs06_p5_bom_foundation_test.sql
test_cs06_p5_bom_foundation.py
```
