# FIN-P2B Shift Expense Fact Implementation Plan

**Date:** 2026-09-20

1. Commit design/plan safepoint.
2. Add RED source tests for migration, sale CASH->KAS_SHIFT, expense fact/RLS/RPC, generic cash movement fail-closed, and UI permission path.
3. Generate `20260920160000_fin_p2b_shift_expense.sql`.
4. Derive the current `private.post_sale_transaction` definition from canonical source and patch only CASH account mapping.
5. Add immutable `business_expenses`, scoped SELECT RLS, and `finance_post_shift_expense`.
6. Harden `cs05_add_cash_movement` to fail closed.
7. Update Shift API/UI to replace generic cash movement entry with permission-gated Shift Expense form and current-shift expense list.
8. Run focused GREEN + migration registry.
9. Run full `npm run verify`.
10. Commit + push technical safepoint.
11. Apply hosted migration using Supabase migration tooling.
12. Run transaction-scoped hosted regression: permission denial, funded shift, expense posting, idempotency, RLS isolation, expected cash, insufficient balance, and rollback.
13. Check advisors/catalog.
14. Run final verify.
15. Write FIN-P2B checkpoint evidence, update project state/manifest/roadmap note.
16. Run verify after docs.
17. Commit + push final checkpoint; local HEAD must equal remote HEAD.
