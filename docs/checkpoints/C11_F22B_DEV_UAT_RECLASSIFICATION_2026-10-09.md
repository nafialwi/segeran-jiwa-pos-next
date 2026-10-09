# C11-F22B — Reclassification of Existing Supabase as Development/UAT

Date: 2026-10-09. Repository: `nafialwi/segeran-jiwa-pos-next`.
Parent checkpoint: F22 `879fce23e4c0ab76e5d33ee2bef8764b543da870`.

## User clarification and decision

The user explicitly confirmed Segeran Jiwa POS **Next is still in development and its environment may be modified**. Therefore the currently connected Supabase project **may be used as the DEV/UAT backend**, rather than requiring a third paid Supabase project immediately.

- DEV/UAT project: `pkynjaqrxhhnnfuaxoqp` (`segeran-jiwa-pos-next`).
- This classification depends on the declaration **no real ongoing business operations are using it**; recheck before destructive operations or exposing to real staff/customers.
- **Do not use the separate KDKMP Supabase project**.
- The existing F22 `staging-isolation-gate.mjs` remains correctly BLOCKED for a _separate production-versus-staging_ check; do not weaken it or mislabel this single-project DEV setup as isolated staging.
- A distinct production backend should be provisioned/configured and independently verified before go-live. Source code can remain the same; deployment config must differ.
- `CUTOVER_READY=NO`; no production deployment or manifest promotion is authorized.

## Actual database read-only inventory

Supabase project is ACTIVE_HEALTHY, PostgreSQL 17. Read-only API checks (no user identity information or secrets exported):

| Data type                            | Count / status   |
| ------------------------------------ | ---------------- |
| Auth users                           | 2                |
| Profiles                             | 2 ACTIVE         |
| Active business memberships          | 1 OWNER, 1 KASIR |
| Stock items                          | 68               |
| Sale products                        | 30               |
| Sales                                | 7 COMPLETED      |
| Shifts                               | 2 OPEN, 3 CLOSED |
| Operation receipts                   | 33               |
| Audit events                         | 29               |
| Purchase orders / production batches | 0 / 0            |
| Public RLS policies                  | 60               |

Existing data is **not empty**. Preserve it as a debugging baseline and avoid reset, TRUNCATE, mass DELETE, automatic migration replay, or closing existing shifts without checking owner intent and taking a recoverable backup.

## Security/configuration review before go-live

Supabase Security Advisor (as of 2026-10-09) reports:

- 10 `rls_enabled_no_policy` INFO findings. Absence of table policies can be intentional if data is accessible only through tightly authorized RPCs; audit the intended access paths before altering policies.
- 4 `anon_security_definer_function_executable` WARN findings: `xp_agent_heartbeat_v2`, `xp_claim_job_v2`, `xp_finish_job_v2`, `xp_renew_job_v2`. Explicitly check whether the anonymous execute privilege is intentional, and verify authorization within the functions.
- 71 `authenticated_security_definer_function_executable` WARN findings. Review their in-function authentication/authorization; do not blanket-revoke application-required RPCs.
- 1 Supabase Auth leaked-password protection warning.
- Deployed `identity-admin` and `device-admin` Edge Functions have platform `verify_jwt=false`. Inspect their application-layer authentication and session/device checks before declaring them unsafe or changing their setting.

The local migrations directory has **66 SQL files**; remote migration history records **53 entries** with different version conventions. **Do not run `supabase db push` blindly.** Reconcile actual schema and migration history first.

## Safe next sequence

1. **No data mutation yet:** obtain/verify a restorable development database backup and document existing shift/transaction baseline.
2. Reconcile SQL migrations, deployed RPCs, RLS grants and Edge Function authorization against source without exposing credentials.
3. Use current Owner and Kasir test accounts via the existing preview. Verify login and available screens without monetary writes first; record genuine results in F21 UAT workbook, keeping pending cases pending.
4. Only after the safety baseline is verified, execute **clearly tagged synthetic** test transactions on this development database (cash checkout, payment methods, stock, PO receiving, production, refund, close shift, reports), checking before/after deltas and idempotency.
5. Fix issues and rerun automated gates; do not distort production facts or claim human UAT when only fixture tests pass.
6. For go-live later: create separate production project, migrate/seed production data deliberately, configure production frontend, re-run environment isolation and security checks, freeze manifest/commit and obtain explicit production approval.

## Scope of checkpoint

This update documents **read-only database checks and development environment designation**. No SQL writes, auth account mutations, migrations, backup restore, Edge Function redeploy, Cloudflare deploy, or live transaction occurred.

**Overall estimated completion remains ~76%, not a release certification.** UAT acceptance and final release gate remain open.
