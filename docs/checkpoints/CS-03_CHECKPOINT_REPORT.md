# CS-03 CHECKPOINT REPORT

Project: segeran-jiwa-pos-next
Checkpoint: CS-03 Identity Session Permission
Baseline Commit: 1b14418 (merge PR #13, main)
Branch: main
Status: LOCKED (RETROACTIVE CLOSURE - finalisasi LOCK CANDIDATE)

## Retroactive Closure Notice

This checkpoint finalizes the LOCK CANDIDATE report generated 2026-09-10
(CS-03_CHECKPOINT_REPORT.md at repository root). CS-03 was implemented via
the superpowers workflow and merged to main through PRs #11-#13. The
technical work was verified (14 vitest tests PASS), but the final
governance lock was not applied. This report closes that gap per the
CS-02 & CS-03 Closure Audit (2026-09-11, auditor: Qwen via XP handoff,
owner-approved at Human QA gate).

The original LOCK CANDIDATE report at repository root is preserved as a
historical artifact. This document at docs/checkpoints/ is the
authoritative locked record.

No source code is modified by this closure. Only governance artifacts
are added.

## Scope (from design spec)

CS-03 establishes authentication, session, device, user-status, and
permission authority required by every later business module.
Server-side fail-closed:

1. Who is this user?
2. Is the account currently active?
3. Is this session/device still allowed?
4. Is the user a current member of this business?
5. What permission is effective now?
6. Is the requested resource inside the user's allowed scope?

Key decisions:

- Owner highest administrator; no separate Admin role
- Kasir first operational preset
- Username + password login (username permanent, display name editable)
- No public self-signup; first Owner provisioned via Supabase
- RLS server-side; UI hiding is not authorization
- CR-CS03-01: sale requires actor Shift Aktual
- CR-CS03-02: shift ownership immutable + config snapshot

## Technical Evidence (in main)

Commits:

- f797f58 Merge PR #11 (design-r2)
- d0b6552 patch(cs-03): SJPOSNEXT-CS03-IMPLEMENTATION-R1
- 0687cd7 fix(cs-03): map login errors to safe user messages
- 7842776 Merge PR #12 (implementation-r1)
- 37ba506 fix(cs-03): correct bootstrap UUID membership lookup
- 1b14418 Merge PR #13 (bootstrap-uuid-fix-r1)
- cda2c61 docs: add CS-03 checkpoint report
- ea9eb99 chore: format cs03 checkpoint report

Tests:

- tests/cs03-authority.test.ts
- tests/cs03-device.test.ts
- tests/cs03-permission.test.ts
- 14 vitest tests PASS (3 files)
- tests/test_cs03_*.py

CR Supplement:

- docs/decisions/CS-03_CR_SUPPLEMENT.md (CR-CS03-01, CR-CS03-02)

## Verification

Command: npx vitest run tests/cs03-authority.test.ts
tests/cs03-device.test.ts tests/cs03-permission.test.ts
Result: PASS (14 tests, 3 files)

Additional: npm run verify (includes test_cs03_*.py)
Result: PASS (at closure time)

## Implementation Status

Authority: PASS
Device Control: PASS
Permission: PASS

## Decision

CS-03 implementation is COMPLETE and LOCKED via retroactive closure.
LOCK CANDIDATE (2026-09-10) -> LOCKED (retroactive closure).
Roadmap weight 10% is earned upon Final Lock.

Closure approved by: [OWNER - pending Human QA]
Closure date: [pending Final Lock]
Closure mechanism: XP+ 2.1.0 WORK package (docs/checkpoints/ only)
