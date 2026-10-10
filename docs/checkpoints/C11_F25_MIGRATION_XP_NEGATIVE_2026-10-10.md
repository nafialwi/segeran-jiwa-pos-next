# C11-F25 — Live Migration Registry Reconciliation and XP Anonymous Denial

**Date:** 2026-10-10 (WIB)

**Repository:** `nafialwi/segeran-jiwa-pos-next`

**Baseline:** F24 `42a732782c4539cdd88f8cb9dda95c7e79450a5c`

**Branch:** `work/c11e-preuat-readiness-termux`

## Verdict

- **F25 READ-ONLY AUDIT = DONE**; no migration replay, reset, role changes, business write or deployment was run.
- **Hosted logical backup = NOT CREATED / UNVERIFIED**. Termux contains `pg_dump`/Postgres but has no usable hosted PostgreSQL connection/password in the inspected environment; the existing `.env` is frontend configuration, not a hosted dump credential. Synthetic local restore F24 remains a tool capability test, not a hosted recovery proof.
- **MIGRATION_HISTORY = MANUAL_RECONCILIATION_REQUIRED**. Never execute `supabase db push` blindly based on the migration registry.
- **XP anonymous missing-token negative-auth = PASS, 4/4**. This only tests absent authentication, not authenticated/valid agent abuses.
- **DEV_UAT_MUTATION_READY=NO; CUTOVER_READY=NO** remain unchanged.

## Inventory of actual Supabase migration registry

A read-only `list_migrations` call for POS dev project `pkynjaqrxhhnnfuaxoqp` returned 53 registry entries. The repository holds 66 `.sql` files in `supabase/migrations`.

The 53 historical migration versions/names were recorded as _metadata only_ in `docs/checkpoints/C11_F25_SUPABASE_MIGRATION_REGISTRY_2026-10-10.json`. No SQL payload, database rows or credentials were saved. Use:

```bash
python3 scripts/migration-registry-audit.py \
  --local-dir supabase/migrations \
  --remote-registry docs/checkpoints/C11_F25_SUPABASE_MIGRATION_REGISTRY_2026-10-10.json
```

| Classification                                 | Count | Meaning                                                                               |
| ---------------------------------------------- | ----: | ------------------------------------------------------------------------------------- |
| Registry entries in Supabase                   |    53 | remote audit snapshot                                                                 |
| SQL migration files in Git                     |    66 | local source inventory                                                                |
| Exact same version **and** name                |    11 | registry identity matches                                                             |
| Same name, different version                   |    35 | possible registry renumbering; **not proof SQL equals live DDL**                      |
| Supabase entry name absent locally             |     7 | manual source/history reconstruction needed                                           |
| Local migration name absent in remote registry |    21 | may have been applied through consolidated/manual DDL; validate against actual schema |
| Duplicated remote migration name               |     1 | `uat_r1_sale_replay_stock_gate` occurs twice with different versions                  |
| Same version with conflicting names            |     0 | none detected in current snapshot                                                     |

The seven names in remote registry absent from local source are:

```
create_xp_termux_bridge
secure_xp_termux_relay_rls
xp_connector_v2_additive_atomic_claim
xp_connector_v2_isolate_legacy_runner
c11f0a_product_master_finished_good_guard
c11f0a_product_variant_source_sync
c11f0a_product_master_source_sync
```

The 21 local-only migration names encompass CS04 sales, CS05 shifts/cash, CS06 products/inventory/purchases/BOM/production, and `c11f0b_operational_message`, `c11f0c_shift_packaging_reconciliation`. These tables and functions need schema-level mapping. **A matching migration name alone cannot certify that SQL contents or behavior match**. Audit deliberately returns `safe_to_automatically_push_migrations:false`, `safe_to_reset_database:false` even if all names were present.

## Live negative test: XP agent functions

The four `anon`-callable `SECURITY DEFINER` RPCs are known to call `xp_bridge_private.authorize_agent` before any business action, and the function requires `x-agent-token` and validates a hashed token against enabled agents.

A deliberately **unregistered test agent name** and **no token header** were used to call each endpoint on the existing dev project. The four calls returned HTTP 403, SQLSTATE `28000`, denying access:

| Function                | Result     |
| ----------------------- | ---------- |
| `xp_agent_heartbeat_v2` | DENIED 403 |
| `xp_claim_job_v2`       | DENIED 403 |
| `xp_finish_job_v2`      | DENIED 403 |
| `xp_renew_job_v2`       | DENIED 403 |

No real agent token or authorized job ID was used, so no claimed/completed job, heartbeat or lease was changed in these tests. Replay using:

```bash
python3 scripts/dev-uat-xp-anon-negative.py --dev-env .env --live
```

The script defaults to BLOCKED without `--live`, validates the exact dev project, rejects server/secret keys, and prints only HTTP status/error code. **Negative-auth success does not certify full security**, and no existing RLS/grant is modified.

## Work finished vs. remaining

**Finished:** actual read-only comparison of migration metadata, persistent sanitized registry snapshot, reproducible fail-closed comparator, repeatable negative-only XP probes, and 12 structural/logic regression tests for F25.

**Still required:**

1. Obtain the correct hosted PostgreSQL connection from Supabase project **Connect** using an operator-controlled terminal (no password in chat or Git). Direct PostgreSQL uses IPv6 on many free projects; an IPv4-only device may need the displayed **session pooler**. See https://supabase.com/docs/guides/database/connecting-to-postgres .
2. Make current hosted `pg_dump` via the **guarded F24 script** and enter password only when prompted on Termux. Do **not** assume a synthetic dump counts. Preserve the current 7 completed sales, 2 open shifts, 68 stock items, Owner/Kasir accounts and audit history.
3. Make a byte-identical retained copy on **independent protected storage**, validate SHA-256, and test the actual archive on an isolated Postgres restore target. Run F23 backup gate and manually verify recovery proof.
4. Perform schema-level comparison of seven remote-only names and 21 local-only names (objects, grants, function hashes, migrations); do not reset/push an incomplete history.
5. Conduct real Owner/Kasir authenticated UAT and 44 F21 scenarios; test transactions with synthetic data only once a current backup is proven and approved.
6. Re-run security/backup review, all CI tests, and freeze a new release manifest linked to an immutable final commit; provision **separate production backend** before go-live.

The F24 safe export operator guide is `docs/runbooks/DEV_UAT_F24_LOCAL_RESTORE_AND_EXPORT.md`. The security audit of Edge Functions is in F24 and remains scoped to missing/invalid auth. F22's staging-isolation preflight remains valid for future production isolation; using the current POS database for DEV/UAT does not satisfy that distinct-environment check.

## Quality assurance and progress estimate

F25 targeted checks: **12/12 PASS**, including stored snapshot counts and repeatable XP missing-token 4/4 responses. Final local quality gate: repo guard **PASS**, Prettier **PASS**, ESLint **PASS**, TypeScript **PASS**, Vitest **107/107 PASS**, Python **573/573 PASS**, production Vite build **PASS**, git diff check **PASS**. GitHub CI must be checked after push.

**Estimated final readiness remains ~76%**, a planning measure only. The failure of backup/UAT/release gates takes precedence over any numeric progress. No production deployment authorized.
