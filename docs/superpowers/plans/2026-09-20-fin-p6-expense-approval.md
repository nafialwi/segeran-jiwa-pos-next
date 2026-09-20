# FIN-P6 Expense Approval Implementation Plan

1. Commit design/plan planning safepoint.
2. Add RED source tests for rule/request/decision tables, approval-aware RPCs, anti-bypass gate, and UI route.
3. Add migration:
   - expense_approval_rules;
   - expense_approval_requests;
   - expense_approval_decisions;
   - expense_approval_queue;
   - matching-rule helper;
   - canonical expense-posting helper;
   - Owner rule RPC;
   - approval-aware submit RPC;
   - Owner decision RPC;
   - rewrite finance_post_shift_expense with approval-required fail-closed gate.
4. Update exact migration and SQL-test registries.
5. Update Shift API/UI for POSTED/PENDING responses and own request history.
6. Add Owner ExpenseApprovalScreen, route, and Home navigation.
7. Run focused GREEN and full npm run verify.
8. Commit/push technical safepoint.
9. Apply hosted migration.
10. Run transaction-scoped hosted regression:
    - no-rule direct posting;
    - threshold/category matching;
    - pending request has no cash/money effect;
    - direct RPC cannot bypass approval;
    - non-Owner cannot decide;
    - Owner approval posts exactly one expense;
    - rejection posts nothing;
    - approve after closed Shift is denied;
    - idempotency;
    - cashier/Owner RLS boundaries.
11. Check hosted advisors and close checkpoint-owned findings.
12. Run final source verify.
13. Write FIN-P6 checkpoint report and state/manifest/roadmap note.
14. Verify docs, commit/push final checkpoint, confirm local HEAD = remote HEAD.
