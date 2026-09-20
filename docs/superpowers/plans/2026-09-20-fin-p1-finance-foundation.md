# FIN-P1 Finance Foundation Implementation Plan

**Date:** 2026-09-20  
**Baseline:** CS-06 LOCKED_REMOTE at `67f0d9ac1ab022b39a8379480e0f8d53f8bcc23a`

## Task 1 - Plan safepoint

- Add FIN-P1 design and plan.
- Format and verify documentation.
- Commit + push planning safepoint.

## Task 2 - RED source contract

Create:
- `tests/test_fin_p1_finance_foundation.py`
- `supabase/tests/fin_p1_finance_foundation_test.sql` as a transaction-scoped SQL regression contract.

Update migration registry source expectations to require:
- `20260920140000_fin_p1_finance_foundation.sql`

Run the focused tests before creating the migration and record RED.

## Task 3 - Migration implementation

Create `20260920140000_fin_p1_finance_foundation.sql`:

- seed `KAS_SHIFT`;
- replace money account / money movement read RLS with Owner-only policies;
- add private owner/finance helpers where needed;
- add `finance_post_transfer`;
- add `finance_post_owner_capital`;
- add `finance_post_owner_personal_withdrawal`;
- revoke broad execution and grant public RPC execution only to authenticated.

Do not create a second ledger.

## Task 4 - Focused GREEN

Run:
- FIN-P1 Python/source tests;
- migration registry tests;
- SQL-source structural assertions.

Fix only bounded FIN-P1 failures.

## Task 5 - Full local gate

Run `npm run verify`.

Expected:
- format PASS
- lint PASS
- typecheck PASS
- JS PASS
- Python PASS
- build PASS
- diff-check PASS

## Task 6 - Source technical safepoint

Commit and push FIN-P1 source before hosted mutation.

## Task 7 - Hosted migration

Apply FIN-P1 migration with Supabase migration tooling.

Verify:
- KAS_SHIFT exists;
- RLS policies are Owner-only;
- RPC signatures exist;
- view remains security_invoker;
- security advisors do not expose a new unplanned ERROR caused by FIN-P1.

## Task 8 - Hosted behavior regression

Execute bounded transaction-scoped SQL behavior checks where the hosted test context supports them. At minimum verify catalog/policy/RPC contracts and idempotent canonical money movement behavior.

## Task 9 - Final verification and checkpoint

Run `npm run verify` again.

Create:
- `docs/checkpoints/FIN-P1_CHECKPOINT_REPORT.md`
- update `PROJECT_STATE.md`
- update `RELEASE_MANIFEST.json`

Do not award the full 10% finance roadmap bucket yet; FIN-P1 is a partial milestone checkpoint.

Commit + push the final checkpoint safepoint and verify local HEAD equals remote HEAD.
