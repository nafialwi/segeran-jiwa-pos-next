# C11-C — POS, Checkout, Success & History Safe Point

Date: 2026-09-23

## Scope

C11-C converges Refinement 02 presentation while preserving the RC4 transaction and history authorities.

Changed presentation surfaces:

- POS search/category toolbar;
- product cards and honest no-photo product visual fallback;
- cart bar and quantity controls;
- payment method chooser;
- CASH tender/change presentation;
- QRIS / Transfer / Kasbon visual hierarchy;
- checkout primary action;
- payment success dialog;
- transaction history hero, filtering actions, payment/status chips, and transaction action buttons;
- desktop checkout becomes a right-side drawer while mobile keeps the bottom-sheet pattern.

## Authority preserved

The following behavior remains unchanged:

- sales require an open shift;
- server-authoritative catalog and checkout remain in use;
- tracked zero-stock products remain blocked;
- discount authority remains `SALE_DISCOUNT`;
- QRIS remains manual verification;
- Transfer requires explicit received-funds confirmation;
- Kasbon requires an identified customer;
- CASH requires sufficient tender before submit;
- submit remains fail-closed through `canPay`, synchronous submit guard, and stable operation id;
- offline sale mutation remains rejected by the existing online-action boundary;
- refund remains immutable reversal behavior;
- correction remains previewed, online-only, confirmed, and separate from refund;
- no database migration, RPC, table, financial writer, inventory writer, or permission rule was changed.

## Visual convergence

The new UI uses the canonical locked Legacy SVG icon family introduced by C11-A.

Notable convergence:

- search field now has canonical search icon;
- product cards use a consistent branded visual fallback instead of pretending product photography exists;
- cart, quantity controls, payment methods, checkout, success, and history actions use semantic icons;
- mobile POS is two-column at narrow phone width with larger touch-oriented cards;
- payment choices become icon-led cards;
- success state gains a stronger completion hierarchy;
- history transactions expose readable payment/status chips;
- desktop checkout moves to a side drawer to approximate the Refinement 02 desktop composition without changing checkout behavior.

## Verification

- focused C11-C + Sales frontend tests: PASS;
- online action and C1 shell Vitest tests: PASS;
- TypeScript: PASS;
- full canonical verify: PASS;
- JavaScript: **96/96 PASS**;
- Python: **313/313 PASS**;
- repo guard / Prettier / ESLint / production build / diff-check: PASS.

## Release status

C11-C is a development safe point only.

RC4 remains immutable and is still the last accepted release candidate.
Production automatic deployment remains disabled.
RC5 must not be created until C11-D, C11-E, and C11-F are complete.
