# P5C Backup and Restore Checkpoint

Date: 2026-09-21

## Verdict

LOCKED_REMOTE. Backup health is HEALTHY and isolated restore is PASS.

## Evidence

A real logical archive was created from project pkynjaqrxhhnnfuaxoqp using PostgreSQL pg_dump 18.6 against hosted PostgreSQL 17.

Included schemas: public, private, auth, and xp_bridge_private.

Connector job/event payload data was excluded from the archive because it is transport history rather than application business state.

Archive TOC entries: 1210.

A byte-identical retained copy was written outside the WSL project filesystem. Source and retained-copy SHA-256 values match.

The archive was restored into an ephemeral local PostgreSQL 18.6 cluster. Restore return code: 0.

Verified restored counts:

- public.businesses: 1
- public.profiles: 1
- public.stock_items: 68
- public.sales: 6
- auth.users: 1
- private.schema_versions: 3

The ephemeral restore cluster was removed after verification. The backup bundle and retained copy remain outside Git.

The temporary read path used for export is now disabled and has no pg_read_all_data membership.

No Production deployment, application migration, application table mutation, or business-row mutation was performed.

## Verification

Feature commit: bdf1f51f248016a562ce0f042d1e691780ad143b

Pre-UAT canonical regression:

- JavaScript: 91/91 PASS;
- Python: 205/205 PASS;
- format check: PASS;
- lint: PASS;
- typecheck: PASS;
- production build: PASS;
- git diff --check: PASS.

## Next action

Run full pre-UAT regression and create the immutable UAT release candidate.
