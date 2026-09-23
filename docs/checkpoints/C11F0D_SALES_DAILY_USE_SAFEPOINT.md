# C11-F0D — Sales Daily-Use Safe Point

Date: 2026-09-23

## Goal

Close the remaining daily cashier friction in Jual without changing checkout
authority or historical sale truth.

## Completed

### Product discovery density

The Jual catalog now offers a per-device 2 / 3 / 4 card density control.

- 2 columns prioritizes readability;
- 3 columns balances scanning speed and detail;
- 4 columns is intentionally compact for fast visual lookup;
- the choice is stored only as a local visual preference;
- no business rule or sale data depends on the preference.

### Transaction-state reset

A successful transaction now resets the next checkout draft to:

- Tunai;
- zero cash received;
- no selected Kasbon customer;
- QRIS confirmation off;
- Transfer confirmation off;
- discount cleared;
- transaction note cleared.

Search and category filters are intentionally retained so repetitive sales in
the same product group remain fast.

This closes the observed state residue where Kasbon/QRIS/Transfer from the
previous sale could still look selected on the next transaction.

### Post-sale refresh

After checkout succeeds, the screen no longer reruns the entire page load
sequence.

It refreshes only the authoritative sales catalog for the current shift
location in the background. This:

- avoids refetching the open shift after every successful sale;
- avoids switching the whole Jual screen back into a blocking loading state;
- keeps stock availability fresh;
- prevents a catalog-refresh failure from being misrepresented as a failed
  checkout.

Checkout remains server authoritative.

### Loading perception

Initial Jual loading now uses a compact search/product skeleton rather than a
large blank-style card. Shift status also no longer claims "Shift aktif" before
the shift lookup has completed:

- loading: "Memeriksa shift…";
- open: "Shift aktif";
- none: "Shift belum aktif".

### Touch residue

Quantity, payment-method, quick-cash, and density controls release transient
pointer focus after taps. Coarse-pointer CSS also disables sticky mobile hover
visuals on product cards and removes browser tap-highlight residue.

This targets the previously observed "jejak klik" behavior without changing
the controlled payment state.

## Authority preserved

No database migration is introduced by C11-F0D.

The screen still uses:

- checkoutSale -> checkout_sale_v2;
- the stable operation/idempotency guard;
- requireOnlineAction for sale mutation;
- server-side inventory and payment validation;
- immutable historical sale/component snapshots.

No direct sales-table mutation was added.

## Verification

Focused C11-C + C11-D + C11-F0D checks pass.

Canonical verification:

- JavaScript: **96/96 PASS**;
- Python: **370/370 PASS**;
- repository guard: PASS;
- Prettier: PASS;
- ESLint: PASS;
- TypeScript: PASS;
- production build: PASS;
- git diff-check: PASS.

## Next

Continue C11-F0E for remaining operational UX residue outside the primary Jual
path, then C11-F final responsive/regression QA and the complete user guide.
