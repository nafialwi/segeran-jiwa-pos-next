# C11-F1 — Interaction Convergence Safe Point

Date: 2026-09-23

## Purpose

C11-F1 starts the final human-operability hardening after the Legacy-vs-Next audit.
The goal is not to copy Legacy architecture, but to carry forward the useful
interaction principles: immediate press feedback, visible action results, and
mobile master-detail continuity.

Baseline before this work:

- branch: work/c11-visual-convergence
- baseline commit: 42933f1d8b9e85f9a08c4c9431406d594484a4db
- Production application: untouched
- database/schema authority: unchanged

## Interaction foundation added

- all normal buttons/links receive touch-action manipulation and an immediate
  pressed-state transform so a tap is visibly acknowledged;
- reduced-motion preference is respected;
- primary route changes return the viewport to the visible start of the new route;
- contextual success/error surfaces touched in this batch expose status/alert
  semantics without changing business behavior.

## Action-result visibility closed in this batch

The following existing screens now actively reveal the result of the user's action:

- Reports: generated report scrolls into view after loading;
- Transaction History: Refund and Correction work surfaces scroll into view and
  receive programmatic focus when opened;
- Product & Recipe: on narrow screens, selecting a product brings its detail panel
  into view instead of leaving the user at the list;
- Inventory Control / Stock Count: selecting an existing count on mobile reveals
  the stock-count workspace above the history list;
- Owner Users: selecting a user on mobile reveals the permission/device detail
  area rather than leaving the user at the user card.

These changes are presentation/navigation behavior only. They do not add a new
transaction, inventory, finance, shift, permission, or reporting authority.

## Explicitly not completed yet

C11-F1 is not the final C11 lock. Remaining planned hardening includes:

- visual geometry and typography normalization;
- removal/replacement of remaining browser-native prompt/confirm surfaces where
  an internal deliberate dialog is more appropriate;
- Product Media upload/replace/remove/compress and Jual catalog integration;
- bottom navigation replacement of Perhatian with permission-safe Laporan;
- remaining screen-by-screen interaction and mobile keyboard/input ergonomics;
- 320/360/390/412 + desktop real-device matrix;
- full Owner/Kasir UAT and final regression.

## Verification

Focused C11-F1 tests:

- 6/6 PASS

Canonical verification after implementation:

- repo guard: PASS
- Prettier: PASS
- ESLint: PASS
- TypeScript: PASS
- JavaScript: 96/96 PASS
- Python: 381/381 PASS
- production build: PASS
- git diff --check: PASS

Build emitted only the existing Vite ineffective-dynamic-import advisory for
src/lib/supabase.ts; it is not introduced by C11-F1.

## Safety conclusion

This is a safe source checkpoint for the first Interaction Convergence batch.
The baseline business authorities remain unchanged and Production remains blocked.

Next execution target: C11-F2/F3 focused-surface + visual geometry/typography
convergence, followed by Product Media and daily navigation/report refinement.
