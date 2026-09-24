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

## C11-F1 safe checkpoint — interaction convergence

The final human-operability hardening has started from the C11-F0E safe baseline.

- normal buttons/links now provide immediate press feedback and touch-action handling;
- primary route changes return to the visible start of the destination;
- Reports reveals the generated result after load;
- History reveals Refund/Correction work surfaces and focuses them;
- mobile Product selection reveals its detail panel;
- mobile Stock Opname history selection reveals the count workspace;
- mobile User selection reveals permission/device detail;
- touched success/error feedback surfaces expose status/alert semantics;
- no transaction, inventory, finance, shift, permission, report authority, or database schema was changed;
- Production remains untouched.

Canonical verification: **96/96 JS + 381/381 Python PASS**, plus repo guard,
Prettier, ESLint, TypeScript, production build, and diff-check.

See: docs/checkpoints/C11F1_INTERACTION_CONVERGENCE_SAFEPOINT.md

## C11-F2 safe checkpoint — visual geometry & readability

C11-F2 normalizes the human-facing visual layer without changing business authority.

- reusable typography/readability tokens were added;
- button/input/select/textarea typography now converges;
- common controls use a 44px daily touch target;
- common card/control/sheet radius families were normalized;
- long text is overflow-safe on key flex/grid/table surfaces;
- daily-use micro/caption text was raised or normalized across Dashboard, Inventory,
  Product, Shift, Purchase, Control Center, Finance, Users, packaging, and search;
- Jual product-card text remains compact at 4-column density but no longer uses the
  earlier micro-sized product-name floor;
- phone form controls use 1rem font size for legibility and zoom-safe input;
- mobile bottom-sheet vs desktop-dialog corner behavior remains context-aware;
- no database migration or authority change was added;
- Production remains untouched.

Focused C11-F2 regression: **7/7 PASS**.
Canonical verification: **96/96 JS + 388/388 Python PASS**, plus repo guard,
Prettier, ESLint, TypeScript, production build, and diff-check.

See: docs/checkpoints/C11F2_VISUAL_GEOMETRY_READABILITY_SAFEPOINT.md

## C11-F3 safe checkpoint — daily navigation & reports

C11-F3 moves the primary navigation toward daily-use work while preserving report
authority.

- Perhatian is removed from the primary bottom/sidebar navigation;
- Laporan becomes the permission-gated primary destination for users who already
  hold REPORT_SALES_LIMITED, REPORT_INVENTORY, or REPORT_PURCHASE;
- Perhatian remains available under Menu -> Operasional;
- /perhatian now belongs to the Menu primary family;
- Reports default to Hari ini and add quick period controls for Hari ini, 7 hari,
  Bulan ini, and Custom;
- changing report period/date clears stale result state before a new report is run;
- existing C11-F1 result reveal and Excel export remain intact;
- no report permission is newly granted to KASIR in this batch because the current
  REPORT_SALES_LIMITED projection is business-wide rather than cashier-own-only;
- no database migration or business-authority change was added;
- Production remains untouched.

Focused regression: **6/6 C11-F3 Python + 5/5 C1 navigation PASS**.
Canonical verification: **96/96 JS + 394/394 Python PASS**, plus repo guard,
Prettier, ESLint, TypeScript, production build, and diff-check.

See: docs/checkpoints/C11F3_DAILY_NAVIGATION_REPORTS_SAFEPOINT.md

## C11-F4 safe checkpoint — responsive reports & mobile readability

C11-F4 closes the real-device report readability defect found after C11-F3.

- phone report rows now render as readable cards instead of crushed wide tables;
- Product cards prioritize Product / Category / Code and Sales cards prioritize
  Transaction Number / Status / Date;
- other report families receive a bounded generic mobile-card fallback;
- tablet/desktop tables preserve minimum geometry and no longer collapse labels into
  near-vertical fragments;
- loaded results support display-only search, Product category filtering,
  Sales payment-method filtering, and safe Qty/Value ordering where columns exist;
- display filters do not redefine report summary facts or Excel export content;
- report dates render in human-readable Indonesian form;
- odd final KPI cards span the mobile row and report content reserves bottom-nav safe area;
- `report_run`, report permissions, database/schema, and all business writers are unchanged;
- Production remains untouched.

Focused C11-F4 regression: **6/6 PASS**.
Canonical verification: **96/96 JS + 400/400 Python PASS**, plus repo guard,
Prettier, ESLint, TypeScript, production build, and diff-check.

See: `docs/checkpoints/C11F4_RESPONSIVE_REPORTS_SAFEPOINT.md`

## C11-F4.1 safe checkpoint — compact report list & drill-down

C11-F4.1 refines report density after C11-F4 real-device review.

- all report families now share one universal compact-list interaction pattern;
- phone rows show only the minimum identity/supporting facts needed for scanning;
- tapping a row opens an internal detail sheet containing every existing report column;
- desktop table rows use the same detail-on-demand surface;
- report sections paginate at 20 rows per page on phone and desktop;
- search/filter/sort changes reset pagination and stale detail state;
- phone KPI cards are tightened without dropping the readability floor;
- long technical metadata remains searchable and available in detail rather than
  making every list row tall;
- pagination and drill-down operate only on the already-authorized report envelope;
- report RPC, permissions, summaries, Excel export truth, database/schema, and
  business writers are unchanged;
- Production remains untouched.

Focused C11-F4.1 regression: **6/6 PASS**.
Canonical verification: **96/96 JS + 406/406 Python PASS**, plus repo guard,
Prettier, ESLint, TypeScript, production build, and diff-check.

See: `docs/checkpoints/C11F41_COMPACT_REPORT_DRILLDOWN_SAFEPOINT.md`

## C11-F4.2 safe checkpoint — report information architecture & semantic density

C11-F4.2 corrects the semantic hierarchy discovered during real-device review of
the compact report UI.

- all report families still use one universal compact-list + detail pattern;
- compact row identity is now selected by report code + section key;
- Finance money flow prefers source/reason/reference context instead of generic
  movement type such as INCOME as the primary identity;
- customer debt uses customer identity and outstanding balance rather than OPEN
  as the row identity;
- supplier payable and employee kasbon likewise use the party identity first;
- normal statuses are quiet while non-normal/action-relevant statuses can surface;
- Finance customer debt is presented as Piutang Pelanggan without changing its
  backend key or contract;
- phone row height is reduced to a 52px minimum;
- section count chips no longer stretch across phone width;
- report empty states and search/filter area are more compact;
- pagination remains 20 rows per page;
- report RPC, permissions, summaries, Excel authority, schema, and business writers
  are unchanged;
- Production remains untouched.

Focused report regression: **18/18 PASS**.
Canonical verification: **96/96 JS + 412/412 Python PASS**, plus repo guard,
Prettier, ESLint, TypeScript, production build, and diff-check.

See: `docs/checkpoints/C11F42_REPORT_INFORMATION_ARCHITECTURE_SAFEPOINT.md`

## C11-F5 safe checkpoint — Product Media & Catalog Completion

C11-F5 adds optional product presentation media while preserving all sale,
inventory, finance, shift, purchase, BOM, and historical transaction authorities.

- new optional `sale_products.image_path` source contract;
- dedicated `product-media` bucket with 2 MB object limit and image MIME bounds;
- storage mutation is tenant/product scoped and requires `PRODUCT_MANAGE`;
- media pointer writes use audited/idempotent `set_sale_product_image`;
- browser-side source validation and compression: JPG/PNG/WebP, 12 MB source,
  1200 px maximum edge, <= 2 MB stored object;
- replace uses upload-new -> switch pointer -> best-effort old cleanup;
- remove clears pointer before best-effort storage cleanup;
- Product Master supports preview, choose/replace, and remove;
- new products must be saved before media upload;
- media capability failure does not disable ordinary Product Master editing;
- Product Operations shows image thumbnails/hero when available;
- Jual warms images after authoritative catalog first paint, so missing/slow media
  never blocks selling;
- placeholder remains the fallback when image is absent or fails to load;
- migration source is prepared but **not applied to Production**;
- unmigrated backend stays fail-closed for media and continues to work without it.

Focused F5 regression: **8/8 PASS**.
F5 + migration source-control regression: **14/14 PASS**.
Canonical verification: **96/96 JS + 420/420 Python PASS**, plus repo guard,
Prettier, ESLint, TypeScript, production build, and diff-check.

See: `docs/checkpoints/C11F5_PRODUCT_MEDIA_SAFEPOINT.md`

Next planned source stage: **C11-F6 — Daily Interaction Cleanup / input-mode sweep**.

## C11-F6 safe checkpoint — Daily Interaction Cleanup

C11-F6 removes the remaining browser-native daily-use interaction traps before
the full responsive matrix.

- one global `ActionDialogProvider` now provides in-app confirm/prompt flows;
- application source no longer uses `window.confirm`, `window.prompt`, or
  `window.alert`;
- Legacy import, refund, correction, operational-message cancellation, Owner
  personal withdrawal, Owner password/device administration, and expense
  approval decisions use the shared dialog;
- canceling an expense-approval prompt now truly aborts the decision;
- destructive actions have explicit consequence copy and danger treatment;
- dialog focus, Escape/backdrop cancel, and background scroll lock are handled
  consistently;
- all JSX numeric inputs declare `inputMode="numeric"` or
  `inputMode="decimal"` according to their quantity semantics;
- touch/coarse-pointer focus remains keyboard-accessible through
  `:focus-visible`;
- no F6 database migration, writer, permission, route authority, or Production
  deployment is introduced.

Focused C11-F6 regression: **7/7 PASS**.
C11-F6 + affected historical safety regression: **33/33 PASS**.
Canonical verification: **96/96 JS + 427/427 Python PASS**, plus repo guard,
Prettier, ESLint, TypeScript, production build, and diff-check.

See: `docs/checkpoints/C11F6_DAILY_INTERACTION_CLEANUP_SAFEPOINT.md`

Next planned source stage: **C11-F7 — Full Responsive & Visual Matrix**.

## C11-F7 safe checkpoint — Responsive & Visual Matrix

C11-F7 adds a final cross-screen responsive guardrail layer before real-device
UAT.

Reference matrix widths:

- 320 / 360 / 390 / 412 px phone;
- 768 px tablet;
- 1024 / 1440 px desktop.

Hardening includes:

- bounded root/screen/panel/form/grid/control widths;
- accidental page-level horizontal overflow containment;
- local horizontal scrolling retained for tables and workflow/tab strips;
- flex/header wrapping on phone and tablet;
- shared action rows distribute safely below 760 px and stack full-width at
  420 px and below;
- tighter card/chip spacing at 360 px and below;
- input/select/textarea width bounding;
- media/preformatted content width bounding;
- existing report phone compact-list vs desktop/table presentation remains
  separated;
- POS/search/Product Master/Action Dialog/report-detail sheet/modal responsive
  contracts remain intact;
- no inline JSX `minWidth` traps across current screen source;
- bottom-nav safe-area reservation remains intact;
- no F7 database migration or authority change.

Focused F7 responsive matrix: **11/11 PASS**.
Canonical verification: **96/96 JS + 438/438 Python PASS**, plus repo guard,
Prettier, ESLint, TypeScript, production build, and diff-check.

This is a source responsive safe point. Browser chrome, soft keyboard,
real-device touch feel, and Owner/Kasir role workflows are intentionally left
for C11-F8 real-device UAT.

See: `docs/checkpoints/C11F7_RESPONSIVE_VISUAL_MATRIX_SAFEPOINT.md`

Next planned stage: controlled F5 Product Media backend activation for UAT,
then **C11-F8 — Owner/Kasir real-device UAT**.
