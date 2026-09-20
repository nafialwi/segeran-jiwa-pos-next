# FIN-P2A Shift Funding Bridge Implementation Plan

**Date:** 2026-09-20

1. Commit this design/plan as planning safepoint.
2. Add RED source tests requiring FIN-P2A migration, RPC, provenance fields, legacy positive-open guard, and frontend funded-open call.
3. Implement `20260920150000_fin_p2a_shift_funding_bridge.sql`.
4. Update `shift-api.ts`, `ShiftManagementScreen.tsx`, shift types/error mapping, and focused JS tests.
5. Run focused GREEN tests and migration registry tests.
6. Run full `npm run verify`.
7. Commit + push technical source safepoint.
8. Apply migration with Supabase migration tooling.
9. Run transaction-scoped hosted Owner/Kasir funded-opening regression and rollback.
10. Run security advisor and catalog checks.
11. Run final `npm run verify`.
12. Write `FIN-P2A_CHECKPOINT_REPORT.md`, update state/manifest/roadmap note, commit + push final safepoint.
