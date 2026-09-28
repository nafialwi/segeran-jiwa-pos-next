# C11 Visual Professionalization & Precision Roadmap — 2026-09-28

## Status and authority

- Status: PLANNED / REQUIRED BEFORE C11 FINAL LOCK.
- Baseline source: `work/c11e-preuat-readiness-termux @ a71d051`.
- This roadmap is a sub-gate of the existing final 5% cutover-hardening bucket.
- It does not create a new project weight and does not change the current 95.0% earned progress.
- Functional correctness and authority boundaries remain mandatory; visual work must not weaken them.
- Final visual acceptance is expressed as `V-PASS`; automated green checks alone do not grant V-PASS.

## Objective

Make Segeran Jiwa POS Next professional, precise, clean, mobile-first, comfortable for daily use, and visually consistent across Kasir and Owner flows.

The target is not decorative redesign. The target is faster scanning, less clutter, consistent geometry, predictable interaction, readable typography, and no layout regression on real devices.

## Current acceptance state

- Functional gate: substantially PASS.
- Architecture/authority gate: substantially PASS with production hardening remaining.
- Visual structure: PARTIAL PASS.
- Visual precision: NOT YET.
- UX cleanliness: NOT YET.
- Real-device visual acceptance: REQUIRED.
- C11 Final Lock: BLOCKED until V-PASS plus the remaining human UAT gates are clear.

## V-P0 — Visual defect closure

1. **Sales quantity badge position**
   - Current complaint: quantity/in-cart number can render below the product image instead of as a stable overlay.
   - Required change: anchor the quantity badge inside a dedicated product-image wrapper with an explicit positioning context and z-index.
   - Acceptance: badge remains top-right of the image/card visual at 320, 360, 390/412, tablet, and desktop widths; no overlap with product name/price.

2. **Sales real-device regression**
   - Re-test header, search, category strip, product card, grid selector, cart bar, bottom navigation, and checkout sheet on Android.
   - Acceptance: no horizontal overflow, clipped text, floating elements, unexpected wrapping, or controls hidden by the software keyboard.

## V-P1 — Sales/POS professional hierarchy

1. Preserve the compact Sales header work already implemented; verify that the real rendered header is compact and does not waste vertical space.
2. Reduce the vertical stack before the first product card:
   - combine or compact product-count/grid controls;
   - keep search and category access fast;
   - move the first catalog row higher.
3. Simplify product cards to prioritize:
   - image;
   - product name;
   - price.
4. Show secondary status only when informative: out of stock, low stock, or multiple variants.
5. Remove redundant visual noise such as permanent `Pilih produk` badges and repeated category text when category filtering is already visible.
6. Use 2 columns as the safe mobile default unless a real-device UAT proves 3 columns equally readable; retain 3/4 as explicit user density choices.
7. Define a readable minimum font floor for product names, prices, secondary labels, status chips, and bottom navigation.

## V-P1 — Clean business language

Replace developer/internal terminology in user-facing UI with operational language.

Required cleanup includes:

- `READ MODEL` and ledger architecture explanations on Reports;
- `Product/Variant` where `Produk & Varian` is clearer;
- `BOM Produksi`, `ingredient sale-stage`, `finished good`, and compatibility wording where simpler Indonesian operational terms are sufficient;
- other implementation-language labels that expose architecture rather than user intent.

Acceptance: Kasir and Owner screens can be understood without software-development or database vocabulary.

## V-P1 — Owner/admin action hierarchy

1. Reduce same-weight action clutter on User and Device cards.
2. Keep primary daily actions visible.
3. Move destructive/rare actions such as reset password, leave/disable, revoke/remove device into a controlled secondary menu or detail flow.
4. Preserve confirmation, permission, and audit behavior.
5. Simplify long permission editing surfaces into grouped, scannable sections without changing permission semantics.

## V-P1 — Reports, history, and long-list usability

1. Make quick report periods the primary path; expose custom date range only when requested.
2. Keep summary information compact and drill down on demand.
3. Ensure long transaction/report lists do not become oversized card stacks; 100 transactions must remain practical to review.
4. Selected detail should appear immediately and predictably, not far below the current viewport.
5. Preserve full transaction/shift detail readability on mobile.

## V-P2 — Visual system convergence

1. Standardize page-header geometry across Sales, Operations, Reports, Finance, History, and secondary screens.
2. Normalize spacing rhythm, card radius, control radius, section gaps, icon sizing, and status-chip geometry.
3. Reduce unnecessary combinations of gradient + radial gradient + border + shadow.
4. Prefer mostly flat/light surfaces with subtle borders; reserve strong elevation for cart bars, dialogs, sheets, and truly floating surfaces.
5. Preserve clear active, selected, success, warning, danger, disabled, loading, and offline states.
6. Keep touch targets usable without making cards and lists unnecessarily tall.

## V-P2 — CSS visual authority consolidation

- Current risk: `src/app.css` contains layered C11 overrides for the same high-impact selectors.
- Do not perform a risky visual rewrite before UAT.
- Consolidate repeated authority for high-risk selectors after the visible defects are closed, especially Sales header/card/badge, shared headers, buttons, cards, reports, and responsive breakpoints.
- Split or reorganize CSS only when behavior can be preserved by regression tests.
- Acceptance: one clear final authority per critical visual selector, no unexplained cascade dependency, and no regression in the existing automated suite.

## Mandatory interaction regressions

Re-test previously reported stale-state behavior:

- quantity +/- feedback;
- Cash / QRIS / Transfer / Kasbon selection;
- payment confirmation state after completing a sale;
- shift open/close input state;
- software keyboard and bottom-sheet behavior;
- click/tap feedback and focus visibility.

Acceptance: a new transaction/shift begins with the correct clean state and no visual residue from the previous flow.

## Real-device visual matrix

Minimum matrix:

- 320 px smoke test;
- 360 px Android;
- 390–412 px Android-class viewport;
- tablet;
- desktop;
- long product names and long labels;
- software keyboard open;
- 2/3/4-column catalog modes;
- light and dark/appearance states where supported.

## Execution order

1. V-P0 quantity-badge defect and Sales real-device reproduction.
2. V-P1 Sales hierarchy/card simplification and compact first-paint.
3. V-P1 business-language cleanup.
4. V-P1 Owner/admin action hierarchy.
5. V-P1 Reports/history long-list cleanup.
6. V-P2 shared visual-system convergence.
7. V-P2 CSS authority consolidation.
8. Full visual matrix plus existing functional/authority regression.
9. Human visual acceptance.
10. Only then mark `V-PASS` and proceed to final C11 regression/freeze.

## Acceptance rule

A visual item may be marked CLOSED only when it is implemented and verified on the intended viewport/device. A commit name, CSS rule, or automated source assertion is not enough.

C11 visual exit requires:

- V-P0 = 0 open;
- V-P1 = 0 open;
- accepted/documented V-P2 only;
- no P0/P1 functional regressions;
- no authority/security weakening;
- real-device evidence recorded;
- Owner/Kasir human acceptance recorded.

Until all criteria above are true, report the project as:
`C11-E AUTOMATED PRE-UAT PASS / VISUAL-INTERACTION ACCEPTANCE PENDING / FINAL LOCK NOT YET`.
