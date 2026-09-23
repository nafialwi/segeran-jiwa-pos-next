# C11 — Visual Refinement Convergence Context Lock

Date: 2026-09-23

## Baseline

- RC4 remains immutable at `uat-rc-20260922-4`.
- C11 branch: `work/c11-visual-convergence`.
- C11 starts from the post-UAT documentation HEAD after RC4.
- Production automatic deployment remains disabled.

## Visual source of truth

The four approved Segeran Jiwa POS Next refinement boards are the visual target:

1. Application Shell & Dashboards
2. Sales, Checkout & History
3. Inventory, Recipe, Purchase, Production & Shift
4. Settings, Finance, Users, Attention, Backup & Health

RC4 remains the behavioral and security source of truth.

## Non-negotiable boundary

C11 is a presentation convergence phase. It must not weaken or replace:

- transaction authority;
- inventory authority;
- finance authority;
- shift integrity;
- permission/role enforcement;
- offline fail-closed boundaries;
- backup evidence truthfulness;
- security-definer hardening;
- database/source-of-truth semantics.

Any functional change discovered as necessary must be treated as a separately reviewed blocker, not hidden inside visual work.

## C11-A — Brand & Icon System

Canonical UI icon authority is the Legacy locked production SVG family:

`segeran-jiwa-pos-legacy/src/assets/icons/locked`

Evidence:

- locked manifest authority: `SEGERAN_JIWA_ICON_FAMILY_SYSTEM_HANDOFF_LOCKED_B01_B05 / Batch 05 cumulative production set`;
- production SVG count: 61;
- checksum manifest retained with the copied family.

The old POS Next 24 px PNG subset is no longer the canonical icon source.

Brand-logo note: the standalone Segeran Jiwa logo/wordmark asset is not present in the Legacy icon family and remains a separate brand asset task.

## Execution order after C11-A

- C11-B: Shell, dashboard, navigation, menu
- C11-C: POS, cart, checkout, success, history
- C11-D: Inventory, product/recipe, purchase, production, shift
- C11-E: Settings, finance, users/devices, attention, backup/health/offline
- C11-F: 320/360/390/412 px mobile QA + desktop QA + full regression
- RC5 only after C11-F passes

Production remains blocked until RC5 acceptance.

## C11-B safe checkpoint — Shell, brand, dashboard & menu

C11-B keeps RC4 behavior intact while converging the visible shell toward Refinement 01.

Implemented:

- the user-supplied Segeran Jiwa logo is now the canonical brand asset for login, AppShell, and dashboard identity surfaces;
- the temporary `SJ` placeholder tile is removed from AppShell;
- dashboard KPI/action icons now use semantic members of the locked Legacy SVG family;
- Menu keeps the existing permission/route authority but uses semantic inventory, restock, reports, cash, approval, purchase, and shift icons;
- mobile header, bottom navigation, dashboard hero, KPI cards, menu cards, and desktop sidebar receive refinement styling without new business data;
- brand asset provenance and SHA-256 are recorded in `public/brand/manifest.json`;
- no database migration, transaction writer, stock writer, finance writer, shift authority, permission boundary, or offline boundary was changed.

Verification at this checkpoint:

- JavaScript: 96/96 PASS;
- Python: 309/309 PASS;
- repo guard / format / lint / TypeScript / production build / diff-check: PASS.

### Packaging/consumables architecture remains canonical

Cup, straw, plastic, seal, tissue, and similar consumables remain Stock Items with `item_kind = PACKAGING`.
A sale variant can bind packaging requirements through `variant_sale_components` with
`component_role = PACKAGING`. Checkout snapshots the consumed components into immutable
`sale_item_component_snapshots`. Shift packaging usage is projected through
`shift_packaging_usage(uuid)` and the physical count continues through Inventory Stock Count.
This preserves the expected-vs-physical basis needed to expose packaging variance by shift
without creating a second cup-specific inventory engine.

## C11-C safe checkpoint — POS, checkout, success & history

Refinement 02 presentation convergence is complete at the source level.

- POS/cart/checkout/history presentation converged using the locked Legacy icon family;
- product cards use an honest branded placeholder instead of fake product photography;
- mobile checkout remains bottom-sheet based; desktop checkout uses a right-side drawer;
- QRIS/Transfer/Kasbon/CASH guards and checkout authority remain unchanged;
- refund/correction behavior remains unchanged;
- no migration or business-authority change was introduced;
- canonical verify: **96/96 JS + 313/313 Python PASS**, plus repo guard, format, lint, TypeScript, build, and diff-check.

See:
`docs/checkpoints/C11C_POS_CHECKOUT_HISTORY_SAFEPOINT.md`

## C11-D safe checkpoint — operations & loading efficiency

Refinement 03 source convergence is complete.

- Inventory, Product/Recipe, Purchase, Production, and Shift received mobile-first visual convergence;
- Jual first paint no longer waits for customer and QRIS support data;
- Product initial render no longer waits for BOM picker options;
- Purchase operational and finance reads resolve progressively;
- Shift active state can render while locations continue loading;
- Inventory detail navigation uses in-flight request prefetch/de-duplication without stale retained cache;
- Production uses honest loading skeletons instead of false empty states;
- no database migration or business-authority change was introduced;
- canonical verify: **96/96 JS + 320/320 Python PASS**, plus repo guard, format, lint, TypeScript, build, and diff-check.

See:
`docs/checkpoints/C11D_OPERATIONS_PERFORMANCE_SAFEPOINT.md`

## C11-E safe checkpoint — control center & mobile usability

Refinement 04 source convergence is complete.

- Control Center is grouped into Business/People/System mental models;
- Finance, Users, Devices, Attention, Backup, Health, Offline, and Diagnostics are visually converged;
- unbounded entity lists no longer rely on disruptive Android native selects;
- a shared searchable mobile bottom-sheet picker is used across Stock Control,
  Sales Kasbon, Purchase, Recipe/BOM, and Finance where lists can grow;
- short finite enumerations remain native controls;
- active horizontal navigation is automatically scrolled into view;
- no database migration or business-authority change was introduced.

See docs/checkpoints/C11E_CONTROL_CENTER_MOBILE_USABILITY_SAFEPOINT.md

## C11-F0A safe checkpoint — Product Master completion

The pre-final functional gap closure has started.

C11-F0A adds a permission-bounded Product Master authority and editor:

- new PRODUCT_MANAGE permission;
- create/update product metadata and active state;
- create/update variant name/code/price/mode/active/default;
- configure sale-stage Ingredient and Packaging components;
- derive FINISHED_GOOD server-side for stock-backed variants;
- keep production BOM as the separate versioned production authority;
- preserve historical sale snapshots;
- mutations are online-only, idempotent, audited RPCs with no client table DML;
- editor is fail-closed behind a backend capability probe;
- migration source is prepared but not applied to Production.

Canonical source verification: **96/96 JS + 338/338 Python PASS**, plus repo guard,
format, lint, TypeScript, production build, and diff-check.

See docs/checkpoints/C11F0A_PRODUCT_MASTER_SAFEPOINT.md

## C11-F0B safe checkpoint — operational messages

The Refinement 01 Cashier Dashboard message placeholder is now backed by a
source-level, permission-bounded operational instruction capability.

- authorized management can target all cashiers or a specific active user;
- messages have Normal/Important priority and a bounded validity window;
- Cashier Dashboard shows current targeted instructions and read acknowledgement;
- management can see read progress and cancel active instructions;
- the feature is deliberately not a general chat system;
- direct message-table access is not granted to the client;
- create/cancel commands are permission checked, idempotency bounded, and audited;
- migration source is prepared but Production is untouched;
- an older backend remains fail-closed through the capability probe.

See:
`docs/checkpoints/C11F0B_OPERATIONAL_MESSAGE_SAFEPOINT.md`

## C11-F0C safe checkpoint — shift packaging reconciliation

Shift packaging is now reconciled through the canonical Inventory Stock Count
authority instead of a second cup-specific engine.

- Opening/Closing packaging checkpoints extend `inventory_counts`;
- Opening cannot be reconstructed after the first sale;
- theoretical use remains sourced from immutable sale component snapshots;
- Closing physical count and variance come only from real inventory count facts;
- stale Closing snapshots are detected after subsequent packaging movements;
- old count facts remain immutable and can be superseded by a fresh checkpoint;
- mobile Shift UI exposes Opening, Theoretical Usage, Expected Closing,
  Physical Closing, and Variance;
- older backends fall back to the existing C10 theoretical-usage authority and
  never fabricate physical data;
- migration source is prepared but Production remains untouched.

See:
`docs/checkpoints/C11F0C_SHIFT_PACKAGING_RECONCILIATION_SAFEPOINT.md`

## C11-F0C.1 live editability / identity hotfix

The shared preview backend now has the C11-F0A Product Master mutation capability applied. DIRECT_STOCK/PREPRODUCED variant saves re-establish the system FINISHED_GOOD component server-side so editor use cannot break checkout component shape.

Owner user/device administration Edge Functions now support browser preflight and keep POST authorization inside the function: bearer token validation, active Segeran Jiwa session, and Owner authority are still mandatory. Raw SJ_IDENTITY_ADMIN_FAILED/SJ_DEVICE_ADMIN_FAILED frontend messages were replaced with human-readable errors.

Frontend Production remains blocked. See docs/checkpoints/C11F0C1_EDITABILITY_IDENTITY_HOTFIX.md.

## C11-F0D safe checkpoint — sales daily-use completion

Jual now supports 2/3/4 product-card density as a per-device visual preference,
resets completed-payment draft state back to Tunai, refreshes only the
authoritative catalog after a successful sale instead of rerunning the whole
screen load, uses honest progressive loading/shift text, and removes coarse
touch/focus residue.

Checkout V2 authority, idempotency, inventory validation, payment guards, and
historical snapshots are unchanged. No C11-F0D database migration is added.

See docs/checkpoints/C11F0D_SALES_DAILY_USE_SAFEPOINT.md.

## C11-F0E safe checkpoint — shift state and mobile interaction

Shift daily-use state is now explicit and reset-safe.

- physical closing cash starts empty instead of implying zero;
- variance is unavailable until a real physical cash value is entered;
- successful open/close uses inline feedback instead of blocking browser alert;
- opening, closing, expense, and packaging transient drafts are cleared across shift boundaries;
- mobile tap residue is suppressed on Shift controls;
- packaging reconciliation is still not a hidden hard close gate;
- shift, reconciliation, packaging, and inventory authorities are unchanged.

See: docs/checkpoints/C11F0E_SHIFT_STATE_MOBILE_INTERACTION_SAFEPOINT.md
