# C11-F24 — Backup & Auth Negative Test Operator Guide

Date: 2026-10-10 (WIB). Project `segeran-jiwa-pos-next`, Supabase project ref `pkynjaqrxhhnnfuaxoqp`.

## Current facts (do not confuse test-fixture success with backup success)

- Project is still **DEV/UAT**, not active production, by owner declaration.
- Hosted data is not empty: 7 completed sales, 5 shifts (2 still open), 68 stock items, 2 user profiles. **Do not reset or close shifts automatically.**
- `pg_dump`, `pg_restore`, `postgres`, `initdb`, `pg_ctl` run on Termux (PostgreSQL 18.2).
- **F24 successful local test:** a private, temporary, Unix-socket-only PostgreSQL server was created; 2 synthetic rows totaling 4500 were dumped, restored and validated. No hosted Supabase query or transaction. Cluster was removed afterward.
- **F24 real negative-auth test:** hosted `identity-admin` and `device-admin` each refused missing and deliberately invalid Bearer JWT, HTTP **401 / SJ_AUTH_REQUIRED**, 4/4. This is a narrow negative control; valid Owner/Kasir role test is pending.
- No active `PGHOST`, `PGUSER`, `PGPASSWORD`, `DATABASE_URL`, or `~/.pgpass` present in the Termux shell at audit. Existing browser env `.env` contains frontend configuration, **not a database dump password**.
- F23 backup-health gate remains **BLOCKED / BACKUP_HEALTH_UNVERIFIED**, and mutations during UAT remain **NO**.

## Safe repeatable commands (no credentials required)

From repository root:

```bash
bash scripts/dev-uat-local-restore-smoke.sh
# ISOLATED_RESTORE_SMOKE=PASS
# HOSTED_SUPABASE_CONTACTED=NO

python3 scripts/dev-uat-edge-auth-negative.py --dev-env .env --live
# F24_LIVE_NEGATIVE_AUTH=PASS checks=4
```

**Security:** The negative-auth tool uses only a publishable (public) key read in memory from the already-existing local env. It does not print it or use any Owner, Kasir, service-role or database password. The requested action is an intentionally unrecognized marker. There are no business writes. Both tests require the development project ref to match the known POS project.

## How to create an ACTUAL development backup, later

The export script `scripts/dev-uat-export-pg.sh` is **not run automatically**. It requires `--execute` plus a valid Supabase DEV endpoint; it rejects unrelated domains and projects. It uses `pg_dump -Fc` over encrypted TLS (`PGSSLMODE=require`) and prompts for the PostgreSQL password interactively via `--password`.

1. In the Supabase Dashboard for **segeran-jiwa-pos-next** (ref above), open **Connect** and choose a valid **direct PostgreSQL** or **session pooler** connection. Copy only the host, port, database and username into the command. **Do not paste the password into chat or CLI arguments.** Prefer proper certificate validation where the connection environment supports a trusted CA. The basic script requests TLS but does not independently prove the remote certificate chain.
2. Use the exact host/user supplied by the dashboard. On a session pooler, the username commonly includes the project ref. For example (replace host and port from actual dashboard):

   ```bash
   cd ~/WORKSTATION/projects/segeran-jiwa-pos-next
   bash scripts/dev-uat-export-pg.sh \
     --host 'db.pkynjaqrxhhnnfuaxoqp.supabase.co' \
     --port 5432 \
     --user postgres \
     --dbname postgres \
     --execute
   ```

   The example direct host may be unreachable from an IPv4-only network; use the _actual_ session pooler endpoint/port and `postgres.pkynjaqrxhhnnfuaxoqp` username if needed, not invented connection details.

3. When requested by PostgreSQL, enter the password **on your own trusted Termux terminal**. Do not display/screenshot it. If the connection fails, no complete valid archive is accepted.
4. A successful export writes an archive and checksum manifest under `~/WORKSTATION/BACKUPS/SEGERAN_JIWA_DEV_DB/backup-...`, **outside Git**. It does **not** create or fabricate a `restore-verification.json`.
5. Make a retained copy to a _truly independent_ protected storage location (ideally off-device) and verify SHA-256. A second folder on the same phone alone is not disaster-safe.
6. Test the **actual** archive by restoring to a separate isolated PostgreSQL target and verifying the essential schemas/counts. Don't use the live development database as restore destination. The synthetic smoke test is **not a substitute for this**.
7. Only after verified full restore and independent retained copy, create actual `restore-verification.json`, check:

   ```bash
   node scripts/backup-health.mjs <bundle-dir> <off-device-copy>
   node scripts/dev-uat-backup-gate.mjs \
     --bundle-dir <bundle-dir> \
     --retained-copy <off-device-copy> \
     --baseline-utc 2026-10-09T16:52:00Z \
     --project-ref pkynjaqrxhhnnfuaxoqp
   ```

   The two validator files do not access Supabase; they check submitted evidence only. They cannot certify that a claimed restore truly occurred. Human review remains required.

## Remaining gates

- ACTUAL hosted logical dump and off-device retained copy: **NOT DONE**.
- ACTUAL isolated restore of hosted dump: **NOT DONE**.
- Successful verified backup evidence tied to current database: **NOT DONE**.
- Live Owner/Kasir permissions and 44 human UAT checks: **NOT DONE**.
- Current-HEAD migration parity, production isolation, final security sign-off and production cutover: **NOT DONE**.

**Do not run `supabase db reset`, `db push`, or financial/stock UAT writes based on this preparation alone.** `DEV_UAT_MUTATION_READY=NO`, `CUTOVER_READY=NO`.
