# FIN-P3 Customer Debt Foundation Implementation Plan

**Date:** 2026-09-20

1. Commit this design/plan as a planning safepoint and push GitHub.
2. Add RED source tests for:
   - customer/debt tables and derived balance view;
   - HUTANG_PELANGGAN account;
   - sales customer + shift FK;
   - repaired sale actor/subtotal/shift behavior;
   - CREDIT posting to receivable;
   - customer debt repayment;
   - permissions and private-helper exposure hardening.
3. Add FIN-P3 migration as fix-forward; never edit historical applied migrations.
4. Add SQL integration test and exact migration/test registry entries.
5. Run focused GREEN tests.
6. Run full `npm run verify`.
7. Commit + push technical safepoint.
8. Apply hosted migration through Supabase managed migration tooling.
9. Run transaction-scoped hosted regression with rollback:
   - customer create;
   - permission denial;
   - funded/open shift;
   - CREDIT sale creates debt and HUTANG_PELANGGAN balance;
   - debt sale is bound to actor profile + actual shift;
   - partial CASH repayment creates KAS_SHIFT increase + CASH_IN;
   - partial TRANSFER repayment creates BANK increase;
   - repayment creates no new sale;
   - debt balance transitions OPEN/PARTIAL/PAID;
   - overpayment rejected;
   - idempotency;
   - unauthorized debt read denied;
   - Owner finance linkage visible;
   - all fixtures rolled back.
10. Run Supabase security/performance advisors and fix any new checkpoint-owned findings.
11. Run final full verify.
12. Write FIN-P3 checkpoint report; update PROJECT_STATE / RELEASE_MANIFEST / ROADMAP note.
13. Run verify after docs.
14. Commit + push final checkpoint.
15. Confirm local HEAD equals remote HEAD.

FIN-P3 must not implement unresolved employee Kasbon repayment/deduction or month-close/reopen semantics.
