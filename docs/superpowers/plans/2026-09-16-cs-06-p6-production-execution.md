# CS-06-P6 Production Execution Implementation Plan

<!-- prettier-ignore-start -->

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add single-location production batches that bind an immutable BOM version and atomically consume components plus produce finished goods through the canonical inventory ledger.

**Architecture:** P6 adds `production_batches`, one creation RPC, and one posting RPC. Creation binds the currently ACTIVE BOM; posting locks component stock items, re-reads canonical ledger balances, rejects shortages, and writes one canonical inventory movement containing negative component lines and one positive finished-good line.

**Tech Stack:** PostgreSQL/Supabase migrations, PL/pgSQL, existing CS-02 inventory/idempotency authority, CS-03 permissions, Python `unittest`, XP+ 2.1.0.

**Spec:** `docs/superpowers/specs/2026-09-16-cs-06-p6-production-execution-design.md`

## Global Constraints

- Previous gate: `CS-06-P5-BOM-FOUNDATION — LOCKED_REMOTE`.
- One production batch uses exactly one business and one location.
- Location may be active `WAREHOUSE` or `STORE` and must belong to current business.
- Batch creation binds one ACTIVE BOM version; later BOM activation does not rewrite the batch.
- Production writes require `PRODUCTION_MANAGE`.
- All inventory effects go through `private.record_inventory_movement(...)` exactly once per successful post.
- Component stock cannot go negative; shortage rejects the entire transaction.
- Posted batch is immutable.
- No production UI, HPP, scrap, reversal, reservation, or multi-location sourcing in P6.
- Migration source must classify as `DATA_CHANGE` under XP+ 2.1.0 classifier.
- Migration must not contain destructive/non-transactional classifier tokens.
- Exact package source must pass Python regressions, format preflight, spec JSON validation, and allowed-path replay before delivery.
- Live DB success is claimed only after XP runs migration + SQL regression and reaches `HUMAN_QA`.

---

## File Structure

Create:
- `docs/superpowers/specs/2026-09-16-cs-06-p6-production-execution-design.md`
- `docs/superpowers/plans/2026-09-16-cs-06-p6-production-execution.md`
- `supabase/migrations/20260916083000_cs06_p6_production_execution.sql`
- `supabase/tests/cs06_p6_production_execution_test.sql`
- `tests/test_cs06_p6_production_execution.py`

Modify:
- `tests/test_cs02_migrations.py`

No other project paths are in scope.

### Task 1 — Add RED source contract tests

- [ ] Create `tests/test_cs06_p6_production_execution.py` before the P6 migration exists.
- [ ] Assert production table/RPC names, `PRODUCTION_MANAGE`, hardened search path, canonical inventory writer, stock locking, shortage guard, immutability, RLS/direct-DML revokes, and SQL integration coverage.
- [ ] Mirror XP classifier regex and require final classification `DATA_CHANGE`.
- [ ] Add P6 migration/test filenames to exact-history lists in `tests/test_cs02_migrations.py`.
- [ ] Run focused tests and confirm RED is caused only by missing P6 migration/test files.

### Task 2 — Implement P6 migration

- [ ] Create `public.production_batches` with DRAFT/POSTED constraints and tenant/index support.
- [ ] Enable tenant read RLS; revoke direct client DML; grant authenticated SELECT only.
- [ ] Add `private.guard_production_batch_mutation()` so only the exact DRAFT→POSTED transition can change a row; POSTED facts are immutable.
- [ ] Implement `public.create_production_batch(uuid, uuid, numeric, text) -> jsonb`.
- [ ] Resolve canonical authority and require `PRODUCTION_MANAGE`.
- [ ] Validate active location and active FINISHED_GOOD.
- [ ] Validate positive three-decimal planned output.
- [ ] Lock/select current ACTIVE BOM with `FOR SHARE` and bind its id/version.
- [ ] Use existing idempotency primitives for batch creation.
- [ ] Implement `public.post_production_batch(uuid, numeric) -> jsonb`.
- [ ] On already POSTED + same output return stable idempotent success; different output fails.
- [ ] Lock component `stock_items` in deterministic UUID order before balance reads.
- [ ] Calculate rounded three-decimal requirements from bound BOM; reject zero-after-rounding.
- [ ] Re-read component quantities directly from immutable inventory ledger at batch location; reject shortage atomically.
- [ ] Build deterministic movement lines: negative components by BOM line order, finished good positive last.
- [ ] Call `private.record_inventory_movement(...)` once using `PRODUCTION_POST:<batch-id>`.
- [ ] Mark batch POSTED with actual output, movement id, actor, and timestamp.
- [ ] Harden function privileges and document contracts.

### Task 3 — Add rollback-safe SQL regression

- [ ] Start with `begin;` and finish with `rollback;`.
- [ ] Create deterministic business/auth/location/item fixtures using existing project patterns.
- [ ] Seed component inventory through canonical inventory writer.
- [ ] Build/activate BOM V1 using P5 RPCs.
- [ ] Create production Batch A and prove it binds V1.
- [ ] Create/activate V2 and prove Batch A still binds V1.
- [ ] Post Batch A and assert exact component decrease + finished-good increase at one location.
- [ ] Assert exactly one production inventory movement.
- [ ] Retry same post and prove no duplicate movement.
- [ ] Retry different output and require `PRODUCTION_ALREADY_POSTED_MISMATCH`.
- [ ] Create shortage case and prove no balance changes and batch remains DRAFT.
- [ ] Prove unauthorized cashier cannot create/post.
- [ ] Prove invalid/cross-tenant location rejection.
- [ ] Prove POSTED batch mutation rejects with `PRODUCTION_IMMUTABLE`.

### Task 4 — Anti-repeat preflight

- [ ] Run P6 source tests.
- [ ] Run P5, P4R1, and exact-history Python tests.
- [ ] Run full Python unittest discovery.
- [ ] Emulate XP SQL classifier over exact migration bytes and require `DATA_CHANGE`.
- [ ] Search migration for destructive/non-transactional tokens and require zero matches.
- [ ] Run Prettier check over the exact P6 docs/files; if local Node dependencies are available, run project `format:check`.
- [ ] Validate JSON spec and allowed path coverage after spec generation.
- [ ] Replay final spec operations onto a fresh copy of the locked baseline and rerun focused regressions.

### Task 5 — Build XP WORK spec

Allowed paths are exactly the six files listed above.

Operations:
- `ADD_FILE` design spec
- `ADD_FILE` implementation plan
- `APPLY_DB_MIGRATION` P6 migration
- `RUN_SQL_TEST` P6 SQL regression
- `ADD_FILE` P6 Python source guard
- `REPLACE_FILE` exact-history test

Human QA:
1. Authorized actor can create DRAFT production batch.
2. Batch preserves BOM version captured at creation.
3. Posting consumes BOM components at the batch location.
4. Posting increases finished-good stock at the same location.
5. Same-output retry creates no duplicate stock movement.
6. Insufficient stock rejects posting without partial inventory effect.
7. Unauthorized actor cannot create or post.
8. POSTED batch is immutable.
9. P5 BOM and P4R1 purchase/GRN regression remain clear.

### Task 6 — XP execution gate

- [ ] Build via `xp pkg-build` only after anti-repeat preflight passes.
- [ ] XP source verification must be CLEAR.
- [ ] DB approval must show `Klasifikasi: DATA_CHANGE`.
- [ ] Migration + SQL regression must reach `HUMAN_QA`.
- [ ] Human QA CLEAR.
- [ ] Final Lock must end at `LOCKED_REMOTE (100%)`.

## Self-Review

- Spec coverage: creation, BOM binding, same-location posting, stock guard, concurrency lock, canonical movement, idempotency, immutability, security, SQL regression, anti-repeat preflight, XP gate — covered.
- No placeholders remain.
- Canonical RPC signatures are consistent:
  - `create_production_batch(uuid, uuid, numeric, text) -> jsonb`
  - `post_production_batch(uuid, numeric) -> jsonb`
- Canonical P6 migration/test paths are fixed throughout this plan.

<!-- prettier-ignore-end -->
