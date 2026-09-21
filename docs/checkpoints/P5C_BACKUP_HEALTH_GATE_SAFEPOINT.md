# P5C Backup Health Gate Safepoint

Date: 2026-09-21

## Verdict

**PREPARED_SAFE / NOT YET HEALTHY**

P5C is not LOCKED_REMOTE yet.

The repository now has a fail-closed backup-health validator and an executable zero-cost backup/restore procedure, but the required logical export, retained off-platform copy, and isolated restore verification have not yet been produced.

## Evidence observed before this safepoint

Hosted Supabase project:

- project ref: pkynjaqrxhhnnfuaxoqp;
- status: ACTIVE_HEALTHY;
- PostgreSQL engine: 17;
- PostgreSQL version: 17.6.1.166;
- organization plan: Free.

PC worker environment audit:

- no pg_dump, pg_restore, psql, Docker, or Podman executable was available in the worker PATH at audit time;
- no SUPABASE_ACCESS_TOKEN, SUPABASE_DB_PASSWORD, DATABASE_URL, DIRECT_URL, POSTGRES_URL, PGHOST, PGUSER, or PGPASSWORD was present in the job environment;
- no Supabase CLI local-state directory was present;
- an npx supabase --version capability probe did not complete within the bounded 180-second worker job and timed out;
- no source file or hosted business data was changed by those audits.

Database metadata confirms that business data now exists, so the older CS-02 future-backup condition has become an active cutover requirement.

## Gate added

scripts/backup-health.mjs refuses to report HEALTHY unless all of these are true:

1. dated manifest is valid and belongs to the correct project;
2. logical export exists;
3. logical-export SHA-256 matches the manifest;
4. retained copy exists separately and is byte-identical by SHA-256;
5. restore-verification evidence exists;
6. restore status is PASS;
7. restore evidence is bound to the exact active backup SHA-256;
8. restore method and verification timestamp are recorded.

The validator intentionally does not treat hosted project health or connectivity as backup health.

## Verification of the gate

tests/backup-health.test.mjs proves:

- complete evidence bundle => HEALTHY;
- modified logical export => UNHEALTHY;
- missing restore evidence => UNHEALTHY;
- missing retained copy => UNHEALTHY;
- restore evidence for a different backup checksum => UNHEALTHY.

## Security boundary

No database password, access token, service-role credential, connection string, backup payload, or production data is stored in Git by this safepoint.

Credentials required for the logical dump must be entered locally by the operator and must not pass through the connector job queue or checkpoint documents.

## Progress accounting

P5A and P5B remain LOCKED_REMOTE.

P5C has reached a safe implementation gate but is not complete because real backup/restore evidence does not exist yet.

Therefore:

- whole-project earned progress remains **95.0%**;
- final-hardening bucket earned progress remains **0.0%**;
- Production automatic deployment remains disabled.

## Next action

Execute the P5C logical export using locally supplied database credentials, create the retained copy and SHA-256 manifest, restore to an isolated test target, run the backup-health validator, and only then lock P5C.
