# FIN-P5 Supplier Payable Foundation Implementation Plan

1. Commit design/plan planning safepoint.
2. Add RED source tests.
3. Add fix-forward migration for UTANG_PEMASOK, supplier_payables, supplier_payable_payments, balance view, create/pay RPCs and RLS.
4. Add transaction-scoped SQL integration contract test.
5. Register exact migration/test history.
6. Run focused GREEN and full npm run verify.
7. Commit/push technical safepoint.
8. Apply managed hosted migration.
9. Run hosted rollback regression:
   - permission denial;
   - create payable only from POSTED GRN;
   - liability balance becomes negative;
   - partial KAS_UTAMA payment;
   - partial BANK payment permission;
   - no overpayment;
   - payment is TRANSFER, not EXPENSE/INCOME;
   - derived OPEN/PARTIAL/PAID state;
   - RLS isolation;
   - idempotency.
10. Run hosted advisors and close checkpoint-owned findings.
11. Run final verify.
12. Write FIN-P5 checkpoint evidence/state/manifest/roadmap note.
13. Verify docs, commit/push final safepoint, confirm local HEAD = remote HEAD.
