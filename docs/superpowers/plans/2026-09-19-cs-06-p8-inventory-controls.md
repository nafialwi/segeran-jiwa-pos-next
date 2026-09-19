# CS-06-P8 Inventory Operational Controls Implementation Plan

<!-- prettier-ignore-start -->

**Goal:** Add canonical Stock Opname, inventory adjustment/write-off, and compensating reversal authority without introducing a second stock ledger.

**Architecture:** P8 remains additive. Stock-count and adjustment records are operational/domain facts, while every quantity change is written through `private.record_inventory_movement(...)`. Non-Owner actions require P8 permission plus existing P7 location scope. Stock Opname uses a server-side expected snapshot and fails closed if canonical stock changes before posting.

**Tech Stack:** PostgreSQL/Supabase migrations, PL/pgSQL, CS-02 inventory/idempotency authority, CS-03 permission authority, P7 location scope, Python `unittest`, SQL rollback regression, XP+ 2.1.0.

**Spec:** `docs/superpowers/specs/2026-09-19-cs-06-p8-inventory-controls-design.md`

## Global Constraints

- Previous gate: `CS-06-P7-RESTOCK-TRANSFER — LOCKED_REMOTE`.
- No direct balance edits.
- No generic client inventory writer.
- No silent negative stock.
- Preserve original movement on correction/reversal.
- Reuse P7 `private.has_inventory_location_scope(...)`.
- Migration must classify `DATA_CHANGE`.
- No destructive DDL, `DELETE FROM`, non-transactional SQL, main/master merge, or production deployment.

## File Structure

Create:
- `docs/superpowers/specs/2026-09-19-cs-06-p8-inventory-controls-design.md`
- `docs/superpowers/plans/2026-09-19-cs-06-p8-inventory-controls.md`
- `supabase/migrations/20260919170000_cs06_p8_inventory_controls.sql`
- `supabase/tests/cs06_p8_inventory_controls_test.sql`
- `tests/test_cs06_p8_inventory_controls.py`

Modify:
- `tests/test_cs02_migrations.py`

No other path is in scope.

---

### Task 1 — RED contracts and migration registry

- Add P8 migration/test filenames to `tests/test_cs02_migrations.py`.
- Add `tests/test_cs06_p8_inventory_controls.py`.
- Require Stock Opname tables/state, P8 permissions, location scope, canonical writer calls, stale-snapshot guard, negative-stock guard, reversal linkage, RLS/security-definer boundary, `DATA_CHANGE` classification and transactional SQL regression.

Run:

```bash
python3 -m unittest tests.test_cs06_p8_inventory_controls tests.test_cs02_migrations -v
```

Expected RED before migration/test files exist.

### Task 2 — Stock Opname schema and security

Create:
- `inventory_counts`
- `inventory_count_lines`

Add:
- tenant-read RLS;
- direct-DML revokes;
- state/immutability triggers;
- `INVENTORY_COUNT` permission.

### Task 3 — Stock Opname RPCs

Implement:

```text
create_inventory_count
record_inventory_count
post_inventory_count
```

Required behavior:
- expected quantity is calculated from canonical movement ledger;
- deterministic item locking;
- non-Owner permission + location scope;
- no client-supplied expected quantity;
- posting fails on stale ledger snapshot;
- exactly one movement for non-zero variance;
- retry of already POSTED count does not duplicate movement;
- zero variance posts without creating an empty movement.

### Task 4 — Adjustment / write-off authority

Create immutable `inventory_adjustments`.

Implement:

```text
post_inventory_adjustment
```

Required:
- `ADJUSTMENT` may be positive or negative;
- `WRITE_OFF` must be negative;
- reason required;
- one canonical movement;
- idempotent create/post;
- negative final stock rejected atomically.

### Task 5 — Compensating reversal

Implement:

```text
reverse_inventory_control
```

Required:
- only P8 movement types;
- original preserved;
- inverse lines;
- `reverses_movement_id` populated;
- second reversal rejected;
- replay of same operation returns same reversal;
- reversal cannot create negative current stock.

### Task 6 — SQL integration regression

Regression must verify:
- permission + scope denial;
- scope grant;
- count create/record/post;
- count retry no duplicate movement;
- posted count immutability;
- adjustment replay;
- write-off;
- negative-stock rejection;
- reversal + reversal replay;
- second reversal rejection;
- stale-count snapshot rejection;
- scope revocation enforcement.

All SQL regression remains inside `BEGIN ... ROLLBACK`.

### Task 7 — Full verification and XP gates

Run canonical verification through XP.

Expected flow:

```text
pkg-build
-> scan/apply
-> source verify
-> DB approval
-> migration
-> SQL regression
-> HUMAN_QA
-> Final Lock
-> remote safepoint
-> LOCKED_REMOTE
```

After P8 is LOCKED_REMOTE, perform a final bounded CS-06 closure audit before deciding closure or P9.

<!-- prettier-ignore-end -->
