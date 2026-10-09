# C11-F24 — Isolated Local Restore and Live Negative-Auth Safety Check

**Date:** 2026-10-10 (WIB)

**Repository:** `nafialwi/segeran-jiwa-pos-next`

**Baseline:** F23 `a522956159fe7f72b221b0d434b8662b56afa3fe`

**Branch:** `work/c11e-preuat-readiness-termux`

## Summary and precise completion boundary

- Successfully ran an **isolated PostgreSQL 18.2 local synthetic backup/restore rehearsal** in Termux. The temporary cluster listened **only on its private Unix-domain socket** (no TCP); source fixture had two rows totaling 4500; the restored fixture had exactly two rows and total 4500. The trap deleted temporary cluster/fixture artifacts. This is NOT the hosted Supabase backup or a current restore proof.
- Successfully ran **4 live negative-auth probes** against DEV hosted Edge Functions with only a public publishable key and intentionally missing/invalid Bearer tokens. `identity-admin` and `device-admin` returned HTTP **401 / SJ_AUTH_REQUIRED** for both cases. No recognized business action was requested, and no database writes were performed. Invalid/missing Bearer checks are NOT an authenticated Owner/Kasir role UAT.
- Added reproducible scripts:
  - `scripts/dev-uat-local-restore-smoke.sh` — self-cleaning local synthetic restore test.
  - `scripts/dev-uat-edge-auth-negative.py` — allowlisted safe read/negative-auth probes, opt-in `--live`.
  - `scripts/dev-uat-export-pg.sh` — **operator-only** dev backup export, explicit `--execute` and interactive password via PostgreSQL; only creates unverified backup archive and manifest.
- Added seven Python regression tests for these controls and the dedicated operator runbook `docs/runbooks/DEV_UAT_F24_LOCAL_RESTORE_AND_EXPORT.md`.
- No secrets or hosted business data included in the repository or checkpoint.

## Real operational blockers

1. Termux had no configured `PGHOST`, `PGUSER`, `DATABASE_URL`, database password or `~/.pgpass` for hosted Supabase at audit. The existing `.env` is a frontend/browser env; it is not a database dump credential. **Therefore no hosted dump was attempted or fabricated.**
2. Prior P5C real backup/restore proof is from **2026-09-21**, older than current data. No current restore proof is available. `scripts/dev-uat-backup-gate.mjs` still reports `BACKUP_HEALTH_UNVERIFIED`.
3. Two development shifts remain OPEN; business data and session/stock facts must be preserved.
4. Owner/Kasir authenticated role negative tests, current-HEAD migration/schema parity, genuine end-to-end sale/stock/purchase/refund tests, recovery backup confirmation and production go-live preparation remain pending.
5. The 4 XP/Termux `anon` RPCs employ `authorize_agent` with header token/hash checks; authorization-negative tests for these functions remain pending. Edge admin source checks Owner context and the four runtime negative probes passed; that is only **partial security evidence**.
6. **Do not deploy production, run migrations, reset DB, close shifts, or run transactions just to report progress**. This phase did not change business data, RLS/grants, Supabase migrations or Edge Functions.

## Quality-gate evidence

The new targeted seven tests (including actual local PostgreSQL restore when utilities exist) passed in Termux. Final local quality gate: repo guard **PASS**, Prettier **PASS**, ESLint **PASS**, TypeScript **PASS**, Vitest **107/107 PASS**, Python **561/561 PASS**, Vite production build **PASS**, and git diff check **PASS**. GitHub CI result must be checked after push. Keep `CUTOVER_READY=NO`, `DEV_UAT_MUTATION_READY=NO`.

## Percent toward final

**~76% (unchanged, planning estimate)**. Tool readiness and negative auth prove incremental safe progress but do not fill the pending authenticated business UAT or release signoff buckets. Old C10 99% does not apply to this checkpoint.

## Next safe work

The operator can obtain PostgreSQL connection details in the Supabase DEV Dashboard **without sharing any password** and execute the guarded dump in their own Termux terminal. Then establish an off-device retained copy, isolated restore verification and fresh backup-health evidence. Only afterward start real UAT sales/stock. Meanwhile review existing database migrations and RPC signatures read-only.
