# C11-F6 — Daily Interaction Cleanup Safe Point

Date: 2026-09-24

## Purpose

C11-F6 removes the remaining browser-native interaction traps and finishes the
mobile keyboard/input sweep before the full responsive matrix.

Baseline:

- branch: `work/c11-visual-convergence`
- baseline commit: `f869bb1d4b5bc48a0115aaa2c023b5af359ca93a`
- previous tag: `c11-f5-product-media-safepoint`
- database/schema: unchanged
- business authority: unchanged
- Production: untouched

## Shared in-app action dialog

The application now has one global `ActionDialogProvider` for confirmations and
short prompted input.

It replaces browser-native `window.confirm`, `window.prompt`, and
`window.alert` usage in application source.

The shared interaction supports:

- mobile bottom-sheet geometry and desktop centered modal geometry;
- explicit title, consequence text, confirm and cancel actions;
- destructive/danger emphasis where appropriate;
- text, password, and textarea prompts;
- native form validation for required/min/max length;
- Escape cancellation;
- backdrop cancellation;
- background scroll lock while open;
- deterministic initial focus.

## Workflows converted

The following workflows now use the in-app dialog instead of browser chrome:

- one-time Legacy master import;
- sale refund final confirmation;
- sale correction/reversal final confirmation;
- operational message cancellation;
- Owner personal withdrawal warning/confirmation;
- Owner user password reset;
- device rename;
- device access revoke;
- removed-device deletion;
- combined revoke-and-remove;
- expense approval decision note/rejection reason.

Existing authority and mutation functions remain the same. C11-F6 changes only
how the user confirms/provides the input before those existing commands run.

A cancellation bug in the expense approval prompt is also removed: cancelling
the prompt now aborts the decision instead of turning browser `null` into an
empty reason and continuing.

Password reset remains bounded to 8–72 characters. Device rename remains bounded
to 1–64 characters.

## Mobile numeric keyboard sweep

Every current JSX `input type="number"` now declares a mobile keyboard intent.

- integer/currency/count inputs use `inputMode="numeric"`;
- fractional quantity/yield/inventory inputs use `inputMode="decimal"`.

This was applied across Product Master, Riwayat, Shift, Finance, Production,
Jual, Expense Approval, Inventory Control, Purchase, and Product Operations.

The existing numeric min/step/business validation remains authoritative and is
not replaced by inputMode.

## Touch/focus behavior

The action dialog uses the same touch-safe application controls rather than
browser-native UI.

On coarse-pointer/no-hover devices, non-keyboard focus does not leave an extra
focus outline after a tap, while `:focus-visible` remains available for
keyboard accessibility.

No route, writer, permission, offline queue, report authority, or data projection
is changed by this batch.

## Regression updates

Older source-contract tests that explicitly required `window.confirm` were
updated to require the new in-app `confirmAction` contract instead. Their
underlying safety requirements remain unchanged:

- refund still requires impact preview + explicit confirmation;
- correction still requires preview + explicit confirmation and online guard;
- Owner personal withdrawal still carries the explicit profit/accounting warning;
- POS/history permission and correction/refund boundaries remain unchanged.

## Verification

Focused C11-F6 regression:

- C11-F6 tests: **7/7 PASS**
- C11-F6 plus affected historical safety tests: **33/33 PASS**

Canonical verification:

- JavaScript: **96/96 PASS**
- Python: **427/427 PASS**
- repository guard: **PASS**
- Prettier: **PASS**
- ESLint: **PASS**
- TypeScript: **PASS**
- production build: **PASS**
- `git diff --check`: **PASS**

The existing Vite `INEFFECTIVE_DYNAMIC_IMPORT` advisory for
`src/lib/supabase.ts` remains unchanged.

## Safety conclusion

C11-F6 is a presentation/interaction safe point.

It removes browser-native confirmation/prompt UI and improves mobile input
ergonomics without changing financial, transaction, inventory, shift, purchase,
product, report, or permission semantics.

## Remaining C11 work

Next planned stage:

1. C11-F7 — Full Responsive & Visual Matrix;
2. controlled F5 media backend activation for UAT when appropriate;
3. C11-F8 — Owner/Kasir real-device UAT;
4. C11-F9 — final regression and hardening;
5. C11 Final Lock / RC5 after blockers are zero.
