> **R2 EXECUTION AMENDMENT — 7 September 2026**
>
> The approved architecture and business rules below remain authoritative. Operational values from the original R1 packaging section are superseded by the verified R2 delivery state: `package_type = schema_patch`; base commit `6ea605896c185273023d9fb4ae6e61a0195fb083`; hosted migration history = 10 ordered fix-forward migrations; source package target branch = `work/cs-02-data-authority-r2`. The final checkpoint/roadmap/release-manifest update is intentionally delivered only after the source PR is merged so it can record the actual final merge commit. No historical hosted migration is rewritten.

# CS-02 — Database, Schema & Data Authority Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build and verify the dedicated Segeran Jiwa POS Next PostgreSQL/Supabase data-authority foundation so later POS modules cannot create duplicate stock, money, audit, or idempotency engines.

**Architecture:** PostgreSQL/Supabase is the authoritative business-data store. CS-02 uses append-oriented stock and money movement facts, immutable success receipts for idempotency, server-side RLS, private command helpers, versioned migrations, and deterministic seed data. The existing GitHub `main` remains canonical source authority and the final source change is delivered through the locked Mobile Inbox workflow after hosted-database preflight passes.

**Tech Stack:** Supabase PostgreSQL 17 + Auth + RLS, SQL/PLpgSQL, GitHub private repository, existing Node.js 24/npm verification pipeline, Python 3 standard-library static migration tests, GitHub Mobile Inbox automation, Cloudflare Pages Preview.

**Spec:** `docs/superpowers/specs/2026-09-06-cs-02-database-schema-data-authority-design.md`

## Global Constraints

- Blueprint baseline is exactly `v1.0 FINAL LOCK`.
- CS-01 canonical source anchor is `c7bce7498b27ea6bd5f8c1981597f068ca4f6f53`.
- Current repository schema version before CS-02 is `0`.
- Whole-project weighted progress before CS-02 is `20.0%`.
- CS-02 roadmap weight is `12%`; full lock raises whole-project progress to `32.0%`.
- Use a new dedicated Supabase project named `segeran-jiwa-pos-next`; do not reuse `totalku-core-dev`.
- Zero-cost-first is mandatory. Before project creation, query the exact project cost for the user-selected organization. If the quoted cost is greater than zero, stop before creation and return to the Owner for a zero-cost decision.
- Do not purchase, upgrade, or enable paid Supabase branching automatically.
- No service-role key, database password, access token, or other secret may be committed, placed in Mobile Inbox ZIP payloads, or embedded in the frontend.
- PostgreSQL/Supabase is primary business-data authority; browser cache/local storage is not authoritative.
- RLS is server-side enforcement. Hiding UI controls is never treated as authorization.
- No completed business stock fact may be hard-deleted or edited in place.
- No completed business money fact may be hard-deleted or edited in place.
- No stock balance may be directly written as an authority.
- No money balance may be directly written as an authority.
- Important business writes must be idempotent.
- Failed business commands leave no success receipt and no partial authoritative state.
- `Gudang` and `Gerai` are separate official locations.
- Generic CS-02 ledger append helpers live in a non-exposed `private` schema. Later milestones expose domain-specific RPCs rather than granting browser clients generic ledger-write access.
- All DDL and deterministic seeds are source-controlled migrations.
- Normal user Manual Work Budget remains `LOW`.
- To avoid repeated trial uploads, implementation is preflighted against the dedicated Supabase project first, then delivered to GitHub as one guarded CS-02 source package plus, only if necessary, one final evidence/checkpoint package.
- Existing CS-01 historical red workflow runs are not blockers unless a new regression reproduces the same defect.

---

## Planned Repository Structure

```text
/
├── docs/
│   ├── superpowers/
│   │   ├── specs/
│   │   │   └── 2026-09-06-cs-02-database-schema-data-authority-design.md
│   │   └── plans/
│   │       └── 2026-09-06-cs-02-database-schema-data-authority.md
│   ├── runbooks/
│   │   └── SUPABASE_CS02.md
│   └── checkpoints/
│       ├── CS-02_CHECKPOINT_REPORT.md
│       ├── PROJECT_STATE.md
│       ├── ROADMAP_PROGRESS.md
│       └── RELEASE_MANIFEST.json
├── supabase/
│   ├── migrations/
│   │   ├── 202609060001_cs02_system_metadata.sql
│   │   ├── 202609060002_cs02_identity_and_reference.sql
│   │   ├── 202609060003_cs02_idempotency_and_audit.sql
│   │   ├── 202609060004_cs02_inventory_authority.sql
│   │   ├── 202609060005_cs02_money_authority.sql
│   │   └── 202609060006_cs02_rls_and_grants.sql
│   └── tests/
│       ├── 001_foundation_assertions.sql
│       ├── 002_rls.sql
│       ├── 003_idempotency.sql
│       ├── 004_inventory.sql
│       ├── 005_money.sql
│       └── 006_immutability.sql
└── tests/
    └── test_cs02_migrations.py
```

The project intentionally does not add Supabase client code to `src/` in CS-02. Runtime UI integration belongs to the later identity/permissions/settings milestone.

---

### Task 1: Perform the zero-cost provider and canonical-source preflight

**Files:**
- No repository write.

**Interfaces:**
- Consumes: CS-01 locked checkpoint and the user-selected Supabase organization.
- Produces: a verified zero-cost creation decision, exact canonical base SHA, and one dedicated Supabase project ID.

- [ ] **Step 1: Confirm the canonical source anchor**

Read current `origin/main` and require:

```text
c7bce7498b27ea6bd5f8c1981597f068ca4f6f53
```

If `main` differs, stop and inspect the intervening commits before generating a CS-02 package.

- [ ] **Step 2: Ask the Owner to select the Supabase organization**

The currently discovered organization is:

```text
platformtotalku@gmail.com's Org
organization_id = vrkbmzphutpsrofkkbxw
```

Do not infer consent from account ownership. Require explicit confirmation that CS-02 should use this organization.

- [ ] **Step 3: Query exact project cost**

Use the Supabase project-cost API for the confirmed organization.

Expected zero-cost gate:

```text
project cost = 0
```

If cost is greater than zero, **STOP**. Do not call project creation.

- [ ] **Step 4: Confirm the quoted cost with the Owner**

Repeat the exact provider quote before project creation.

- [ ] **Step 5: Create the dedicated project only after the cost gate passes**

Create:

```text
name   = segeran-jiwa-pos-next
region = ap-southeast-1
```

Record only the non-secret `project_id/ref`.

- [ ] **Step 6: Verify the project is healthy and empty enough for a fresh CS-02 baseline**

List migrations and public tables.

Expected before CS-02 DDL:
- no Segeran Jiwa business migrations;
- no imported legacy POS business tables;
- no reuse of `totalku-core-dev`.

**Gate:** Task 1 passes only when the project is dedicated, zero-cost under the confirmed quote, and no legacy business source was imported.

---

### Task 2: Add the approved spec, plan, runbook, and static migration-test harness

**Files:**
- Create: `docs/superpowers/specs/2026-09-06-cs-02-database-schema-data-authority-design.md`
- Create: `docs/superpowers/plans/2026-09-06-cs-02-database-schema-data-authority.md`
- Create: `docs/runbooks/SUPABASE_CS02.md`
- Create: `tests/test_cs02_migrations.py`

**Interfaces:**
- Consumes: approved CS-02 design and current `npm run verify` Python discovery.
- Produces: repository documentation plus a secret-free static gate automatically included by existing `npm run test:py`.

- [ ] **Step 1: Write the failing static migration test before migrations exist**

Create `tests/test_cs02_migrations.py`:

```python
from __future__ import annotations

import json
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MIGRATIONS = ROOT / "supabase" / "migrations"
SQL_TESTS = ROOT / "supabase" / "tests"

EXPECTED_MIGRATIONS = [
    "202609060001_cs02_system_metadata.sql",
    "202609060002_cs02_identity_and_reference.sql",
    "202609060003_cs02_idempotency_and_audit.sql",
    "202609060004_cs02_inventory_authority.sql",
    "202609060005_cs02_money_authority.sql",
    "202609060006_cs02_rls_and_grants.sql",
]

EXPECTED_SQL_TESTS = [
    "001_foundation_assertions.sql",
    "002_rls.sql",
    "003_idempotency.sql",
    "004_inventory.sql",
    "005_money.sql",
    "006_immutability.sql",
]


class Cs02MigrationTests(unittest.TestCase):
    def read_migrations(self) -> str:
        return "\n".join((MIGRATIONS / name).read_text("utf-8") for name in EXPECTED_MIGRATIONS)

    def test_expected_files_exist(self) -> None:
        self.assertEqual(
            sorted(path.name for path in MIGRATIONS.glob("*.sql")),
            sorted(EXPECTED_MIGRATIONS),
        )
        self.assertEqual(
            sorted(path.name for path in SQL_TESTS.glob("*.sql")),
            sorted(EXPECTED_SQL_TESTS),
        )

    def test_no_secret_like_assignments(self) -> None:
        text = self.read_migrations().lower()
        forbidden = [
            "service_role_key",
            "supabase_service_role_key",
            "database_password",
            "postgres_password",
        ]
        for token in forbidden:
            self.assertNotIn(token, text)

    def test_required_authority_objects_are_declared(self) -> None:
        text = self.read_migrations().lower()
        required = [
            "create schema if not exists private",
            "create table public.businesses",
            "create table public.profiles",
            "create table public.business_memberships",
            "create table public.locations",
            "create table public.stock_items",
            "create table public.operation_receipts",
            "create table public.audit_events",
            "create table public.inventory_movements",
            "create table public.inventory_movement_lines",
            "create view public.inventory_balances",
            "create table public.money_accounts",
            "create table public.money_movements",
            "create view public.money_balances",
            "enable row level security",
        ]
        for token in required:
            self.assertIn(token, text)

    def test_fact_tables_do_not_use_on_delete_cascade(self) -> None:
        text = self.read_migrations().lower()
        fact_tables = [
            "operation_receipts",
            "audit_events",
            "inventory_movements",
            "inventory_movement_lines",
            "money_movements",
        ]
        for table in fact_tables:
            pattern = rf"create table public\.{table}.*?(?=create table|create view|$)"
            match = re.search(pattern, text, re.S)
            self.assertIsNotNone(match, table)
            self.assertNotIn("on delete cascade", match.group(0))

    def test_sql_integration_tests_are_transactional(self) -> None:
        for name in EXPECTED_SQL_TESTS:
            text = (SQL_TESTS / name).read_text("utf-8").strip().lower()
            self.assertTrue(text.startswith("begin;"), name)
            self.assertTrue(text.endswith("rollback;"), name)


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run only this test and verify RED**

Run:

```bash
python3 -m unittest tests.test_cs02_migrations -v
```

Expected: FAIL because `supabase/migrations` and `supabase/tests` do not exist yet.

- [ ] **Step 3: Write the runbook**

`docs/runbooks/SUPABASE_CS02.md` must state:

```text
Authority: PostgreSQL/Supabase
Project: segeran-jiwa-pos-next
Region: ap-southeast-1
Secrets: never committed
DDL: migrations only
Generic ledger writes: private schema only
Client writes: RLS + later domain RPCs
Zero-cost: stop before paid creation/branching
Recovery: migrations + checkpoint + logical backup procedure
```

It must also contain the exact hosted verification order:

```text
1. list migrations
2. apply migration files in filename order
3. run 001..006 SQL tests
4. list tables
5. security advisor
6. performance advisor
7. record non-secret evidence
```

- [ ] **Step 4: Do not add a new package dependency**

The current Node/Python verification toolchain is sufficient. `package.json` and `package-lock.json` remain unchanged in CS-02 unless a real implementation need is discovered and separately justified.

**Gate:** Task 2 is complete when the static test is RED for the intended missing-migration reason and documentation contains no secret.

---

### Task 3: Create migration 001 — private schema and schema-version authority

**Files:**
- Create: `supabase/migrations/202609060001_cs02_system_metadata.sql`
- Test: `tests/test_cs02_migrations.py`
- Test: `supabase/tests/001_foundation_assertions.sql`

**Interfaces:**
- Produces:
  - `private` non-exposed schema;
  - immutable `private.schema_versions` history;
  - CS-02 schema version `1`.

- [ ] **Step 1: Write migration 001**

```sql
create extension if not exists pgcrypto;

create schema if not exists private;

revoke all on schema private from public;
revoke all on schema private from anon;
revoke all on schema private from authenticated;

create table private.schema_versions (
    version integer primary key,
    milestone text not null,
    blueprint_baseline text not null,
    source_anchor text not null,
    applied_at timestamptz not null default now(),
    constraint schema_versions_version_positive check (version > 0),
    constraint schema_versions_blueprint_nonempty check (length(btrim(blueprint_baseline)) > 0),
    constraint schema_versions_source_anchor_sha check (source_anchor ~ '^[0-9a-f]{40}$')
);

insert into private.schema_versions (
    version,
    milestone,
    blueprint_baseline,
    source_anchor
)
values (
    1,
    'CS-02',
    '1.0',
    'c7bce7498b27ea6bd5f8c1981597f068ca4f6f53'
);

create or replace function private.prevent_fact_mutation()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
    raise exception using
        errcode = '55000',
        message = 'SJ_IMMUTABLE_FACT';
end;
$$;
```

- [ ] **Step 2: Write foundation assertion SQL**

Create `supabase/tests/001_foundation_assertions.sql`:

```sql
begin;

do $$
begin
    if not exists (
        select 1
        from private.schema_versions
        where version = 1
          and milestone = 'CS-02'
          and blueprint_baseline = '1.0'
    ) then
        raise exception 'CS02_SCHEMA_VERSION_MISSING';
    end if;
end
$$;

rollback;
```

- [ ] **Step 3: Run static test**

Expected: still FAIL only because migrations 002..006 and SQL tests 002..006 do not yet exist.

---

### Task 4: Create migration 002 — business identity and reference masters

**Files:**
- Create: `supabase/migrations/202609060002_cs02_identity_and_reference.sql`

**Interfaces:**
- Produces:
  - `public.businesses`
  - `public.profiles`
  - `public.access_roles`
  - `public.business_memberships`
  - `public.locations`
  - `public.stock_items`
  - `public.money_accounts`
  - deterministic Segeran Jiwa / Gudang / Gerai / baseline money-account seeds.

- [ ] **Step 1: Create business and profile tables**

Use:

```sql
create table public.businesses (
    id uuid primary key default gen_random_uuid(),
    code text not null unique,
    display_name text not null,
    active boolean not null default true,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    constraint businesses_code_format check (code ~ '^[A-Z0-9][A-Z0-9_-]{1,31}$'),
    constraint businesses_display_name_nonempty check (length(btrim(display_name)) > 0)
);

create table public.profiles (
    id uuid primary key default gen_random_uuid(),
    auth_user_id uuid not null unique,
    display_name text not null,
    status text not null default 'ACTIVE',
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    constraint profiles_display_name_nonempty check (length(btrim(display_name)) > 0),
    constraint profiles_status_valid check (status in ('ACTIVE', 'LEAVE', 'DISABLED'))
);
```

`profiles.auth_user_id` intentionally does not cascade from `auth.users`. Business identity/history must survive authentication-principal lifecycle changes.

- [ ] **Step 2: Create role and membership foundation**

```sql
create table public.access_roles (
    code text primary key,
    display_name text not null,
    owner_level boolean not null default false,
    active boolean not null default true
);

insert into public.access_roles (code, display_name, owner_level)
values
    ('OWNER', 'Owner', true),
    ('KASIR', 'Kasir', false);

create table public.business_memberships (
    id uuid primary key default gen_random_uuid(),
    business_id uuid not null references public.businesses(id) on delete restrict,
    profile_id uuid not null references public.profiles(id) on delete restrict,
    role_code text not null references public.access_roles(code) on delete restrict,
    active boolean not null default true,
    created_at timestamptz not null default now(),
    unique (business_id, profile_id)
);
```

This is a role foundation only. Granular permission tables and management UI belong to the later permissions milestone.

- [ ] **Step 3: Create official locations**

```sql
create table public.locations (
    id uuid primary key default gen_random_uuid(),
    business_id uuid not null references public.businesses(id) on delete restrict,
    code text not null,
    display_name text not null,
    location_type text not null,
    active boolean not null default true,
    created_at timestamptz not null default now(),
    unique (business_id, code),
    constraint locations_type_valid check (location_type in ('WAREHOUSE', 'STORE')),
    constraint locations_code_format check (code ~ '^[A-Z0-9][A-Z0-9_-]{1,31}$')
);
```

- [ ] **Step 4: Create minimal stock-item authority**

```sql
create table public.stock_items (
    id uuid primary key default gen_random_uuid(),
    business_id uuid not null references public.businesses(id) on delete restrict,
    code text not null,
    display_name text not null,
    item_kind text not null,
    base_unit text not null,
    active boolean not null default true,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    unique (business_id, code),
    constraint stock_items_kind_valid check (
        item_kind in ('MATERIAL', 'FINISHED_GOOD', 'PACKAGING', 'OTHER')
    ),
    constraint stock_items_base_unit_nonempty check (length(btrim(base_unit)) > 0)
);
```

This table is intentionally minimal. Full product catalog/pricing/HPP UI is not CS-02 scope.

- [ ] **Step 5: Create money-account master**

```sql
create table public.money_accounts (
    id uuid primary key default gen_random_uuid(),
    business_id uuid not null references public.businesses(id) on delete restrict,
    code text not null,
    display_name text not null,
    account_type text not null,
    active boolean not null default true,
    created_at timestamptz not null default now(),
    unique (business_id, code),
    constraint money_accounts_type_valid check (
        account_type in ('CASH', 'BANK', 'QRIS_UNSETTLED', 'QRIS_SETTLED', 'OTHER')
    )
);
```

- [ ] **Step 6: Seed deterministic business/reference rows without generated-ID literals**

```sql
insert into public.businesses (code, display_name)
values ('SJ', 'Segeran Jiwa');

insert into public.locations (
    business_id,
    code,
    display_name,
    location_type
)
select id, 'GUDANG', 'Gudang', 'WAREHOUSE'
from public.businesses
where code = 'SJ';

insert into public.locations (
    business_id,
    code,
    display_name,
    location_type
)
select id, 'GERAI', 'Gerai', 'STORE'
from public.businesses
where code = 'SJ';

insert into public.money_accounts (
    business_id,
    code,
    display_name,
    account_type
)
select id, code, display_name, account_type
from public.businesses
cross join (
    values
        ('KAS_UTAMA', 'Kas Utama', 'CASH'),
        ('BANK', 'Bank', 'BANK'),
        ('QRIS_BELUM_CAIR', 'QRIS Belum Cair', 'QRIS_UNSETTLED'),
        ('QRIS_SUDAH_CAIR', 'QRIS Sudah Cair', 'QRIS_SETTLED')
) as seed(code, display_name, account_type)
where businesses.code = 'SJ';
```

**Gate:** seed queries must resolve business IDs by business code; no generated UUID is hardcoded into a data migration.

---

### Task 5: Create migration 003 — idempotency success receipts and immutable audit

**Files:**
- Create: `supabase/migrations/202609060003_cs02_idempotency_and_audit.sql`
- Create: `supabase/tests/003_idempotency.sql`

**Interfaces:**
- Produces:
  - `public.operation_receipts`
  - `public.audit_events`
  - `private.payload_sha256(jsonb)`
  - `private.lock_operation(...)`
  - `private.record_operation_success(...)`

- [ ] **Step 1: Create immutable success receipts**

```sql
create table public.operation_receipts (
    id uuid primary key default gen_random_uuid(),
    business_id uuid not null references public.businesses(id) on delete restrict,
    idempotency_key text not null,
    command_type text not null,
    payload_hash text not null,
    result_type text not null,
    result_id uuid not null,
    actor_profile_id uuid references public.profiles(id) on delete restrict,
    created_at timestamptz not null default now(),
    unique (business_id, idempotency_key),
    constraint operation_receipts_key_nonempty check (length(btrim(idempotency_key)) > 0),
    constraint operation_receipts_hash_format check (payload_hash ~ '^[0-9a-f]{64}$')
);

create trigger operation_receipts_immutable
before update or delete on public.operation_receipts
for each row execute function private.prevent_fact_mutation();
```

Only successful commands receive a receipt. If a command transaction fails, its attempted receipt and partial facts roll back together, so the same idempotency key can be retried safely.

- [ ] **Step 2: Create immutable audit events**

```sql
create table public.audit_events (
    id uuid primary key default gen_random_uuid(),
    business_id uuid not null references public.businesses(id) on delete restrict,
    actor_profile_id uuid references public.profiles(id) on delete restrict,
    operation_receipt_id uuid references public.operation_receipts(id) on delete restrict,
    event_type text not null,
    entity_type text not null,
    entity_id uuid not null,
    metadata jsonb not null default '{}'::jsonb,
    created_at timestamptz not null default now()
);

create trigger audit_events_immutable
before update or delete on public.audit_events
for each row execute function private.prevent_fact_mutation();
```

- [ ] **Step 3: Create payload hash helper**

```sql
create or replace function private.payload_sha256(p_payload jsonb)
returns text
language sql
immutable
strict
set search_path = ''
as $$
    select encode(
        extensions.digest(convert_to(p_payload::text, 'UTF8'), 'sha256'),
        'hex'
    );
$$;
```

If Supabase exposes `digest` in a schema other than `extensions`, inspect the installed extension schema and use the actual schema. Do not guess after a runtime failure.

- [ ] **Step 4: Create advisory-lock replay check**

```sql
create or replace function private.lock_operation(
    p_business_id uuid,
    p_idempotency_key text,
    p_command_type text,
    p_payload_hash text
)
returns table (
    replay boolean,
    receipt_id uuid,
    result_type text,
    result_id uuid
)
language plpgsql
security definer
set search_path = ''
as $$
declare
    existing public.operation_receipts%rowtype;
begin
    if p_idempotency_key is null or length(btrim(p_idempotency_key)) = 0 then
        raise exception using errcode = '22023', message = 'SJ_IDEMPOTENCY_KEY_REQUIRED';
    end if;

    perform pg_catalog.pg_advisory_xact_lock(
        pg_catalog.hashtextextended(p_business_id::text || ':' || p_idempotency_key, 0)
    );

    select *
    into existing
    from public.operation_receipts
    where business_id = p_business_id
      and idempotency_key = p_idempotency_key;

    if not found then
        return query select false, null::uuid, null::text, null::uuid;
        return;
    end if;

    if existing.command_type <> p_command_type
       or existing.payload_hash <> p_payload_hash then
        raise exception using errcode = '23505', message = 'SJ_IDEMPOTENCY_CONFLICT';
    end if;

    return query
    select true, existing.id, existing.result_type, existing.result_id;
end;
$$;
```

- [ ] **Step 5: Write idempotency integration test**

`supabase/tests/003_idempotency.sql` must:
1. create a test profile/membership using fixed test UUID values inside the transaction;
2. compute one payload hash;
3. call the private lock helper before a receipt and assert `replay=false`;
4. insert one success receipt;
5. call again and assert `replay=true`;
6. call with the same key and different hash and require `SJ_IDEMPOTENCY_CONFLICT`;
7. rollback all fixtures.

**Gate:** same key/same semantic payload is a replay; same key/different payload is rejected.

---

### Task 6: Create migration 004 — inventory movement authority

**Files:**
- Create: `supabase/migrations/202609060004_cs02_inventory_authority.sql`
- Create: `supabase/tests/004_inventory.sql`

**Interfaces:**
- Produces:
  - immutable inventory movement header/lines;
  - authoritative balance view;
  - private atomic recorder with idempotency and reversal support.

- [ ] **Step 1: Create movement header**

```sql
create table public.inventory_movements (
    id uuid primary key default gen_random_uuid(),
    business_id uuid not null references public.businesses(id) on delete restrict,
    movement_type text not null,
    source_type text not null,
    source_ref text not null,
    reason_code text not null,
    actor_profile_id uuid references public.profiles(id) on delete restrict,
    reverses_movement_id uuid unique references public.inventory_movements(id) on delete restrict,
    created_at timestamptz not null default now(),
    constraint inventory_movements_source_nonempty check (length(btrim(source_ref)) > 0),
    constraint inventory_movements_reason_nonempty check (length(btrim(reason_code)) > 0)
);

create trigger inventory_movements_immutable
before update or delete on public.inventory_movements
for each row execute function private.prevent_fact_mutation();
```

- [ ] **Step 2: Create movement lines**

```sql
create table public.inventory_movement_lines (
    movement_id uuid not null references public.inventory_movements(id) on delete restrict,
    line_no integer not null,
    stock_item_id uuid not null references public.stock_items(id) on delete restrict,
    location_id uuid not null references public.locations(id) on delete restrict,
    quantity_delta numeric(18, 3) not null,
    primary key (movement_id, line_no),
    constraint inventory_lines_line_positive check (line_no > 0),
    constraint inventory_lines_nonzero check (quantity_delta <> 0)
);

create trigger inventory_movement_lines_immutable
before update or delete on public.inventory_movement_lines
for each row execute function private.prevent_fact_mutation();
```

- [ ] **Step 3: Create authoritative balance projection**

```sql
create view public.inventory_balances
with (security_invoker = true)
as
select
    m.business_id,
    l.stock_item_id,
    l.location_id,
    sum(l.quantity_delta)::numeric(18, 3) as quantity
from public.inventory_movements m
join public.inventory_movement_lines l
  on l.movement_id = m.id
group by m.business_id, l.stock_item_id, l.location_id;
```

- [ ] **Step 4: Create private atomic recorder**

Create `private.record_inventory_movement(...)` with this exact interface:

```text
p_business_id uuid
p_actor_profile_id uuid
p_idempotency_key text
p_movement_type text
p_source_type text
p_source_ref text
p_reason_code text
p_lines jsonb
p_reverses_movement_id uuid default null
returns uuid
```

Algorithm:
1. reject null/non-array/empty `p_lines`;
2. compute payload hash from all semantic arguments;
3. call `private.lock_operation`;
4. if replay, require `result_type='INVENTORY_MOVEMENT'` and return existing `result_id`;
5. if reversal target is supplied, require target business matches and no prior reversal exists;
6. validate every JSON line has positive integer `line_no`, UUID `stock_item_id`, UUID `location_id`, and nonzero numeric `quantity_delta`;
7. validate referenced item/location belongs to the same business;
8. insert header;
9. insert all lines;
10. insert one `operation_receipts` row;
11. insert one `audit_events` row;
12. return movement ID.

The function is `security definer`, has `set search_path = ''`, and is not granted to `anon` or `authenticated`.

- [ ] **Step 5: Write inventory integration test**

`supabase/tests/004_inventory.sql` must prove within `begin`/`rollback`:
- a test item exists;
- +10 at Gudang creates Gudang balance 10;
- transfer represented by -3 Gudang and +3 Gerai creates Gudang 7 / Gerai 3;
- replaying the exact transfer key returns the same movement ID and balances remain 7 / 3;
- conflicting reuse of the transfer key fails;
- an invalid location from another business fails;
- a reversal creates a new fact and leaves the original row present.

---

### Task 7: Create migration 005 — money movement authority

**Files:**
- Create: `supabase/migrations/202609060005_cs02_money_authority.sql`
- Create: `supabase/tests/005_money.sql`

**Interfaces:**
- Produces:
  - immutable money movement fact;
  - authoritative money balance view;
  - private atomic money recorder with idempotency/reversal support.

- [ ] **Step 1: Create money movements**

```sql
create table public.money_movements (
    id uuid primary key default gen_random_uuid(),
    business_id uuid not null references public.businesses(id) on delete restrict,
    movement_type text not null,
    from_account_id uuid references public.money_accounts(id) on delete restrict,
    to_account_id uuid references public.money_accounts(id) on delete restrict,
    amount numeric(18, 2) not null,
    source_type text not null,
    source_ref text not null,
    reason_code text not null,
    actor_profile_id uuid references public.profiles(id) on delete restrict,
    reverses_movement_id uuid unique references public.money_movements(id) on delete restrict,
    created_at timestamptz not null default now(),
    constraint money_movements_amount_positive check (amount > 0),
    constraint money_movements_has_direction check (
        from_account_id is not null or to_account_id is not null
    ),
    constraint money_movements_distinct_accounts check (
        from_account_id is null
        or to_account_id is null
        or from_account_id <> to_account_id
    ),
    constraint money_movements_type_valid check (
        movement_type in (
            'INCOME',
            'EXPENSE',
            'TRANSFER',
            'SETTLEMENT',
            'OPENING_BALANCE',
            'ADJUSTMENT',
            'REVERSAL'
        )
    )
);

create trigger money_movements_immutable
before update or delete on public.money_movements
for each row execute function private.prevent_fact_mutation();
```

- [ ] **Step 2: Create balance view**

```sql
create view public.money_balances
with (security_invoker = true)
as
select
    business_id,
    account_id,
    sum(delta)::numeric(18, 2) as balance
from (
    select business_id, to_account_id as account_id, amount as delta
    from public.money_movements
    where to_account_id is not null

    union all

    select business_id, from_account_id as account_id, -amount as delta
    from public.money_movements
    where from_account_id is not null
) x
group by business_id, account_id;
```

- [ ] **Step 3: Create private atomic recorder**

Create `private.record_money_movement(...)` with:

```text
p_business_id uuid
p_actor_profile_id uuid
p_idempotency_key text
p_movement_type text
p_from_account_id uuid
p_to_account_id uuid
p_amount numeric
p_source_type text
p_source_ref text
p_reason_code text
p_reverses_movement_id uuid default null
returns uuid
```

Enforce:
- amount > 0;
- at least one account exists;
- accounts differ;
- all supplied accounts belong to business;
- `TRANSFER` and `SETTLEMENT` require both from/to;
- `INCOME` and `OPENING_BALANCE` require `to_account_id`;
- `EXPENSE` requires `from_account_id`;
- reversal target belongs to business and has not already been reversed;
- same idempotency algorithm as inventory;
- movement + receipt + audit commit atomically.

- [ ] **Step 4: Write money integration test**

`supabase/tests/005_money.sql` must prove:
- opening balance 100000 to Kas Utama gives balance 100000;
- transfer 25000 Kas Utama → Bank yields 75000 / 25000;
- transfer does not create any second income/expense fact;
- exact retry does not change balances;
- conflicting key reuse fails;
- expense 10000 from Kas Utama yields 65000;
- reversal is a new row and original remains queryable.

---

### Task 8: Create migration 006 — RLS, membership helpers, grants, and direct-write denial

**Files:**
- Create: `supabase/migrations/202609060006_cs02_rls_and_grants.sql`
- Create: `supabase/tests/002_rls.sql`
- Create: `supabase/tests/006_immutability.sql`

**Interfaces:**
- Produces:
  - server-side active-member/owner checks;
  - default-deny protected writes;
  - authenticated read policies appropriate to CS-02;
  - no browser access to `private` helpers.

- [ ] **Step 1: Create current-user helper functions**

Create:

```text
private.current_profile_id() returns uuid
private.is_active_member(p_business_id uuid) returns boolean
private.is_owner(p_business_id uuid) returns boolean
```

`current_profile_id()` maps `auth.uid()` to `public.profiles.auth_user_id`.

All helpers are `security definer`, stable where valid, and use `set search_path = ''`.

- [ ] **Step 2: Enable RLS on every public table**

Enable RLS on:

```text
businesses
profiles
access_roles
business_memberships
locations
stock_items
money_accounts
operation_receipts
audit_events
inventory_movements
inventory_movement_lines
money_movements
```

- [ ] **Step 3: Add read policies**

Rules:
- active member may read own business;
- user may read own profile;
- owner may read profiles/memberships for own business;
- active member may read locations/items/accounts and ledger facts of own business;
- no cross-business read.

- [ ] **Step 4: Revoke direct ledger writes**

Explicitly revoke:

```sql
revoke insert, update, delete on public.operation_receipts from anon, authenticated;
revoke insert, update, delete on public.audit_events from anon, authenticated;
revoke insert, update, delete on public.inventory_movements from anon, authenticated;
revoke insert, update, delete on public.inventory_movement_lines from anon, authenticated;
revoke insert, update, delete on public.money_movements from anon, authenticated;

revoke all on all functions in schema private from public;
revoke all on all functions in schema private from anon;
revoke all on all functions in schema private from authenticated;
```

Do not grant generic ledger recorders to browser roles in CS-02.

- [ ] **Step 5: Write RLS integration test**

`002_rls.sql` uses two businesses and two synthetic auth UUID mappings without requiring actual login creation.

Inside the transaction:
1. insert Owner profile/membership for business A;
2. insert Kasir profile/membership for business A;
3. insert profile/membership for business B;
4. `set local role authenticated`;
5. set `request.jwt.claim.sub` to Owner auth UUID;
6. verify Owner sees business A but not business B;
7. switch claim to Kasir UUID;
8. verify Kasir can read allowed business-A reference data;
9. verify direct insert into `inventory_movements` is denied;
10. verify direct insert into `money_movements` is denied;
11. use an unknown auth UUID and verify business rows are invisible;
12. rollback.

- [ ] **Step 6: Write immutability integration test**

`006_immutability.sql` inserts facts through private functions under admin context, then verifies update/delete attempts raise `SJ_IMMUTABLE_FACT`.

**Gate:** RLS is not accepted if direct API role simulation can mutate ledger fact tables.

---

### Task 9: Complete static TDD and preflight the exact source package locally

**Files:**
- All Task 2–8 files.

**Interfaces:**
- Produces: formatter-safe, checksum-ready source payload before the user uploads anything.

- [ ] **Step 1: Run static migration test**

```bash
python3 -m unittest tests.test_cs02_migrations -v
```

Expected: PASS.

- [ ] **Step 2: Run the repository's existing full verification in an isolated canonical checkout if available**

```bash
npm ci
npm run verify
git diff --check
```

Expected: PASS.

If the assistant execution environment does not possess the private canonical checkout, do not fabricate this evidence. The Mobile Inbox worker remains the canonical repository-level verification gate.

- [ ] **Step 3: Run a placeholder scan on new documentation**

Reject before packaging if any new CS-02 doc contains:

```text
TBD
TODO
implement later
fill in details
```

- [ ] **Step 4: Run secret-pattern scan**

At minimum scan new payload for:

```text
service_role
SUPABASE_SERVICE_ROLE_KEY
postgres://
postgresql://
DATABASE_URL=
password=
access_token=
```

Expected: no real secret assignment/value.

- [ ] **Step 5: Validate package paths**

Package may create/modify only:

```text
docs/superpowers/specs/**
docs/superpowers/plans/**
docs/runbooks/SUPABASE_CS02.md
docs/checkpoints/**
supabase/**
tests/test_cs02_migrations.py
```

Do not modify `src/**`, `.github/**`, `tools/mobile_inbox/**`, or the CS-01 workflow as part of CS-02 database foundation.

---

### Task 10: Apply migrations to the dedicated hosted project and run integration tests

**Files:**
- No new source beyond Task 2–8 files.

**Interfaces:**
- Consumes: exact migration SQL intended for the GitHub package.
- Produces: hosted database evidence against the same SQL bytes.

- [ ] **Step 1: Confirm project has no prior CS-02 migration drift**

List migrations immediately before apply.

- [ ] **Step 2: Apply migrations in exact filename order**

Use migration names:

```text
cs02_system_metadata
cs02_identity_and_reference
cs02_idempotency_and_audit
cs02_inventory_authority
cs02_money_authority
cs02_rls_and_grants
```

For DDL, use the migration API, not ad-hoc raw SQL.

- [ ] **Step 3: Verify migration list**

Expected exactly six CS-02 migrations in order.

- [ ] **Step 4: Run SQL integration tests 001..006**

Execute each repository SQL test exactly as stored.

Expected:
- all complete without unhandled exception;
- each ends with rollback, so test fixtures do not persist.

- [ ] **Step 5: Inspect final tables and constraints**

List `public` tables verbosely and confirm foreign keys/PKs for the CS-02 objects.

- [ ] **Step 6: Verify deterministic reference state**

Raw read-only SQL must show:
- one `SJ` business;
- one `GUDANG`;
- one `GERAI`;
- baseline money accounts:
  - `KAS_UTAMA`
  - `BANK`
  - `QRIS_BELUM_CAIR`
  - `QRIS_SUDAH_CAIR`;
- no test fixture profiles/items left after rolled-back tests.

- [ ] **Step 7: Verify schema version**

Require:

```text
private.schema_versions.version = 1
milestone = CS-02
blueprint_baseline = 1.0
```

**Gate:** do not create the GitHub Mobile Inbox package if any hosted integration test fails.

---

### Task 11: Run security/performance review and foundation restore drill

**Files:**
- Modify final contents of `docs/runbooks/SUPABASE_CS02.md`
- Later checkpoint files record evidence.

**Interfaces:**
- Produces: provider-level security gate and reproducibility evidence.

- [ ] **Step 1: Run Supabase security advisors**

No unresolved security finding that invalidates:
- RLS;
- function search paths;
- exposed private helpers;
- missing policy on protected tables.

If a finding is relevant, correct the migration source and re-run on a clean correction migration before packaging.

- [ ] **Step 2: Run performance advisors**

Performance warnings are classified:
- BLOCKER only if they threaten correctness/obvious operational viability at CS-02 scale;
- otherwise record for later optimization without weakening security.

- [ ] **Step 3: Foundation restore/rebuild drill**

Because CS-02 begins on a brand-new empty dedicated project, the initial six-migration application itself is the schema/reference-data rebuild drill.

Record evidence that the project started without legacy business schema and was reconstructed from:
1. six versioned migrations;
2. deterministic seeds;
3. no manual dashboard DDL.

Do not falsely claim a populated production-data restore drill; business production data does not exist in POS Next at CS-02.

- [ ] **Step 4: Document zero-cost backup path**

Runbook must define future logical backup requirements:
- PostgreSQL logical export;
- off-site retained copy;
- SHA-256 checksum;
- dated manifest;
- restore verification before backup is considered healthy.

No paid PITR dependency is introduced.

---

### Task 12: Write CS-02 checkpoint evidence and calculate roadmap progress

**Files:**
- Create: `docs/checkpoints/CS-02_CHECKPOINT_REPORT.md`
- Modify: `docs/checkpoints/PROJECT_STATE.md`
- Modify: `docs/checkpoints/ROADMAP_PROGRESS.md`
- Modify: `docs/checkpoints/RELEASE_MANIFEST.json`

**Interfaces:**
- Consumes: all hosted and source verification evidence.
- Produces: continuity authority sufficient for the next milestone without reconstructing this chat.

- [ ] **Step 1: Write checkpoint report with exact fields**

The report must contain:

```text
Project workspace: Segeran Jiwa Next Vol. 1
Product: Segeran Jiwa POS Next
Tahap: CS-02 — Core System: Database, Schema & Data Authority Foundation
Blueprint baseline: v1.0 FINAL LOCK
Status: QA / LOCKED
Progress tahap:
Progress keseluruhan:
Supabase project ID:
Region:
Schema version:
Migrations:
Static tests:
Hosted integration tests:
RLS:
Idempotency:
Inventory authority:
Money authority:
Immutability:
Security advisor:
Performance advisor:
Restore/rebuild drill:
Manual Work Budget:
Repository / branch / commit:
Production state:
Release guard mode:
Rollback/source anchor:
NEXT ACTION:
```

Never include secrets.

- [ ] **Step 2: Update roadmap only after full acceptance**

When every CS-02 gate passes:

```text
CS-02 milestone completion = 100%
CS-02 earned weight = 12.0%
Whole-project weighted progress = 32.0%
```

If the milestone is still QA, keep earned project progress at `20.0%`.

- [ ] **Step 3: Update release manifest**

Set:
- schema version: `1`;
- CS-02 status;
- non-secret Supabase project ID/ref;
- migration count `6`;
- source checkpoint after final merge;
- next action.

---

### Task 13: Build one guarded Mobile Inbox source package and verify the PR

**Files:**
- Package all approved source files from Tasks 2–12.

**Interfaces:**
- Consumes: hosted-PASS SQL and checkpoint evidence.
- Produces: one verified GitHub working branch/PR/Cloudflare Preview without direct Production mutation.

- [ ] **Step 1: Build package only after Tasks 1–12 PASS**

Manifest:

```json
{
  "package_id": "SJPOSNEXT-CS02-DATA-AUTHORITY-R1",
  "milestone": "CS-02",
  "title": "Database Schema and Data Authority Foundation",
  "revision": "R1",
  "package_type": "patch",
  "blueprint_baseline": "1.0",
  "target_branch": "work/cs-02-data-authority-r1",
  "base_commit": "c7bce7498b27ea6bd5f8c1981597f068ca4f6f53",
  "schema_version_expected": 0,
  "retry_safe": false,
  "files_manifest": [],
  "delete_paths": []
}
```

Populate `files_manifest` with exact SHA-256 values of every payload file.

- [ ] **Step 2: Validate ZIP offline before handoff**

Require:
- one root `package-manifest.json`;
- only declared payload files;
- every payload checksum matches;
- no secret-like file;
- no ZIP-slip path;
- no protected workflow/source change outside CS-02 scope.

- [ ] **Step 3: User performs one normal Android upload**

User action:
`GitHub Web → mobile-inbox → inbox → upload exactly one ZIP → commit`.

No Codespaces/Termux should be required for the normal path.

- [ ] **Step 4: Require worker PASS**

Evidence:
- Mobile Inbox trigger PASS;
- worker PASS;
- `npm run verify` PASS;
- `canonical-verify: success`;
- branch `work/cs-02-data-authority-r1`;
- PR created;
- Cloudflare Preview successful;
- Production `main` unchanged before approval.

- [ ] **Step 5: Review PR scope before merge**

PR may contain only the planned CS-02 files. Reject any unrelated UI/source/workflow change.

---

### Task 14: Merge, run post-merge verification, and lock CS-02

**Files:**
- No new implementation unless a checkpoint evidence correction is genuinely required.

**Interfaces:**
- Produces: canonical CS-02 source/database checkpoint.

- [ ] **Step 1: Merge only after explicit Owner approval**

Do not auto-merge.

- [ ] **Step 2: Run fresh post-merge canonical verification**

From a detached clean worktree with hooks disabled for verification:

```bash
git fetch origin main
git worktree prune
rm -rf /tmp/cs02-postmerge-main
git -c core.hooksPath=/dev/null worktree add --detach /tmp/cs02-postmerge-main origin/main
cd /tmp/cs02-postmerge-main
npm ci
npm run verify
git diff --check
test -z "$(git status --porcelain)"
echo POSTMERGE_MAIN_SHA=$(git rev-parse HEAD)
echo CS02_POSTMERGE_VERIFY=PASS
```

- [ ] **Step 3: Re-check hosted project**

Require:
- migration count still six;
- schema version 1;
- security advisor has no new blocker;
- no test fixtures remain.

- [ ] **Step 4: Delete merged working branch**

Delete `work/cs-02-data-authority-r1` only after post-merge PASS.

- [ ] **Step 5: Final lock declaration**

Only now declare:

```text
CS-02 = 100% FINAL LOCKED
Whole Project = 32.0%
Schema Version = 1
NEXT ACTION = next roadmap milestone after CS-02
```

The exact next milestone name must be taken from the checkpoint/roadmap authority at execution time rather than guessed from chat memory.

---

## Rollback and Recovery Plan

### Before GitHub merge

- Canonical `main` remains at the CS-01 checkpoint.
- Cloudflare Production automatic deployment remains disabled.
- The hosted Supabase project contains only CS-02 foundation data.
- If migration design is wrong, fix forward with a correction migration while there is no production business data.
- Do not destructively rewrite an already-recorded migration on the hosted project and then pretend history did not change.

### After GitHub merge but before later business data

- Source rollback anchor is the final CS-01 commit:
  `c7bce7498b27ea6bd5f8c1981597f068ca4f6f53`.
- Database rollback is **not** implemented as destructive down-migrations that erase valid facts.
- Correct schema mistakes with forward migrations.
- If the entire dedicated project is abandoned before real business use, record that governance decision explicitly; do not silently switch back to `totalku-core-dev`.

### Secrets incident

If any secret is accidentally exposed:
1. stop;
2. revoke/rotate the credential at the provider;
3. remove it from source/history using the approved security process;
4. do not continue merely because tests pass.

---

## Manual Work Budget

Expected: `LOW`.

Normal Owner actions:
1. confirm which Supabase organization to use;
2. confirm the exact quoted project cost;
3. upload one final guarded CS-02 ZIP through GitHub Web;
4. review real PR/Preview evidence;
5. explicitly approve merge/checkpoint.

Everything else—schema design, SQL generation, migration application, integration tests, advisors, package checksums, failure analysis, checkpoint drafting, and verification—is assistant/automation work wherever the available tools permit it.

---

## Self-Review

### Spec coverage

- Dedicated project: Task 1.
- Migration/version authority: Tasks 3, 10, 14.
- Business/profile/location foundation: Task 4.
- Idempotency: Task 5.
- Immutable audit: Task 5.
- Inventory engine: Task 6.
- Money engine: Task 7.
- Reversal foundation: Tasks 6–7.
- RLS/server security: Task 8.
- Error/atomicity model: Tasks 5–8.
- Tests: Tasks 2, 5–10.
- Security advisors: Task 11.
- Backup/restore baseline: Task 11.
- Explicit non-scope: Global Constraints and planned file structure.
- Checkpoint/continuity: Tasks 12–14.
- One-upload clean workflow: Task 13.

### Placeholder scan

This plan intentionally contains no `TBD`, `TODO`, `implement later`, or `fill in details` instructions.

### Type/name consistency

Locked names:
- schema: `private`
- version table: `private.schema_versions`
- idempotency receipt: `public.operation_receipts`
- audit: `public.audit_events`
- inventory facts: `public.inventory_movements`, `public.inventory_movement_lines`
- inventory projection: `public.inventory_balances`
- money master: `public.money_accounts`
- money facts: `public.money_movements`
- money projection: `public.money_balances`
- official locations: `GUDANG`, `GERAI`
- target branch: `work/cs-02-data-authority-r1`
- starting schema version: `0`
- resulting schema version: `1`

No alternate names are authorized during implementation without correcting this plan first.

---

## Execution Handoff

Plan is ready for explicit approval.

Recommended execution mode for this project is **Inline Execution with strict checkpoints**, because the implementation must coordinate:
- private repository Mobile Inbox packaging;
- a connected Supabase account;
- zero-cost provider confirmation;
- hosted migration/advisor evidence;
- one real Android upload/PR gate.

After approval, execution begins with Task 1 only. No database project is created until the Owner confirms the organization and the exact cost quote.
