# FIN-P4 QRIS Settlement & Daily Finance Reconciliation Plan

1. Push design/plan planning safepoint.
2. Add RED source tests.
3. Add fix-forward FIN-P4 migration and transactional SQL integration test.
4. Register exact migration/test history.
5. GREEN focused tests.
6. Full npm run verify.
7. Push technical safepoint to GitHub.
8. Apply managed hosted migration.
9. Run hosted rollback regression:
   - seed QRIS sale money;
   - reject non-Owner settlement;
   - settle gross with zero fee;
   - settle gross with MDR/provider fee;
   - verify QRIS unsettled decreases by gross;
   - verify fee is EXPENSE and sale revenue is unchanged;
   - verify net reaches Bank;
   - verify idempotent settlement;
   - reject settlement above available balance;
   - record daily reconciliation;
   - verify SESUAI case;
   - verify PERLU_DIPERIKSA variance case;
   - verify non-Owner cannot read finance reconciliation;
   - rollback all fixtures.
10. Run security/performance advisors; fix checkpoint-owned findings.
11. Final full verify.
12. Write checkpoint evidence/state/manifest/roadmap note.
13. Verify again after docs.
14. Commit/push final safepoint and verify local HEAD = remote HEAD.
