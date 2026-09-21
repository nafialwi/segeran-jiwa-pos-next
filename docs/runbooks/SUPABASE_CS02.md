# Supabase CS-02 Runbook

## Project

- Project name: `segeran-jiwa-pos-next`
- Project ref: `pkynjaqrxhhnnfuaxoqp`
- Region: `ap-southeast-1`
- Blueprint baseline: `1.0`
- Schema version: `1`
- Hosted migration history: `10` ordered migrations

No database password, service-role key, API access token, or connection string belongs in this repository.

## Canonical migration history

1. `20260906171822_cs02_system_metadata.sql`
2. `20260906171939_cs02_identity_and_reference.sql`
3. `20260906172647_cs02_idempotency_and_audit.sql`
4. `20260906172811_cs02_inventory_authority.sql`
5. `20260906172916_cs02_money_authority.sql`
6. `20260906173018_cs02_rls_and_grants.sql`
7. `20260906173113_cs02_explicit_read_grants.sql`
8. `20260906173248_cs02_restrict_auto_rls_helper.sql`
9. `20260906173339_cs02_performance_hardening.sql`
10. `20260907013121_cs02_correct_schema_source_anchor.sql`

The tenth migration is a fix-forward metadata correction. Migration 001 is preserved exactly as historical source; history is never rewritten to hide the correction.

## Acceptance evidence before source handoff

- hosted project: ACTIVE_HEALTHY;
- schema version 1 / milestone CS-02 / blueprint 1.0;
- deterministic seed: one `SJ` business;
- official locations: `GUDANG`, `GERAI`;
- money accounts: `KAS_UTAMA`, `BANK`, `QRIS_BELUM_CAIR`, `QRIS_SUDAH_CAIR`;
- hosted SQL integration tests 001–006: PASS, each transaction rolled back;
- no residual test profiles, stock items, receipts, inventory movements, or money movements;
- security advisor: no findings;
- performance advisor: INFO-only unused-index observations on a new/empty workload, not a CS-02 correctness blocker.

## Rebuild / recovery

For an empty replacement project, apply the ten source-controlled migrations in filename order, then execute `supabase/tests/001..006` and require each to complete and roll back. Verify deterministic seeds and `private.schema_versions` afterward. The original foundation build plus the recorded fix-forward migrations constitute the CS-02 schema/reference-data rebuild evidence; no populated production-data restore is claimed at this milestone.

## Future zero-cost backup path

When production business data exists, a healthy logical backup requires a PostgreSQL logical export, an off-site retained copy, SHA-256 checksum, dated manifest, and a restore verification. CS-02 introduces no paid PITR dependency.

## GitHub delivery

Normal delivery uses one guarded Mobile Inbox ZIP with `package_type: schema_patch`. The upload creates a working branch/PR/Preview and must not mutate Production automatically. After source PR merge and post-merge verification, a separate checkpoint/evidence package updates `PROJECT_STATE`, `ROADMAP_PROGRESS`, `CS-02_CHECKPOINT_REPORT`, and `RELEASE_MANIFEST` using the actual final merge commit.

## P5C logical backup execution gate

P5C is fail-closed: the application backup must not be described as healthy from project status, browser connectivity, file existence, or a checksum alone.

For the Free-plan hosted project, keep the zero-cost path as a manual PostgreSQL logical export. Database credentials must be supplied locally at execution time and must never be committed to Git, written into connector job commands, copied into checkpoint documents, or pasted into chat.

Preferred export procedure when the operator workstation has the required database connection string and Supabase CLI/Docker:

    mkdir -p "$HOME/WORKSTATION/backups/segeran-jiwa-pos-next/$(date -u +%Y%m%dT%H%M%SZ)"
    cd "$HOME/WORKSTATION/backups/segeran-jiwa-pos-next/"*
    supabase db dump --db-url "$DATABASE_URL" -f roles.sql --role-only
    supabase db dump --db-url "$DATABASE_URL" -f schema.sql
    supabase db dump --db-url "$DATABASE_URL" -f data.sql --use-copy --data-only

If the Supabase CLI path is unavailable, a compatible PostgreSQL logical-export procedure may be used, but it must be documented and must preserve the current application-owned schema/data recovery contract.

After export:

1. produce SHA-256 checksums;
2. create backup-manifest.json with format_version = 1, project ref, UTC creation time, logical-export filename, and SHA-256;
3. retain a byte-identical copy on storage separate from the hosted database and record where it is retained;
4. restore the backup into an isolated PostgreSQL/Supabase test target, never into the active project;
5. record restore-verification.json with status = PASS, UTC verification time, the exact backup SHA-256, and restore method;
6. run npm run backup:health -- <bundle-dir> <retained-copy-file> and require BACKUP_HEALTH=HEALTHY.

BACKUP_HEALTH=UNHEALTHY is a cutover blocker.

The backup bundle itself is sensitive operational data and must stay outside this Git repository.
