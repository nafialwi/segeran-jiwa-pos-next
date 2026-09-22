# REFINEMENT CONVERGENCE CONTEXT LOCK — 22 September 2026

## Purpose

Dokumen ini adalah context-recovery authority untuk Segeran Jiwa POS Next setelah RC1.
Tujuannya mencegah pengulangan audit/analisis dari nol dan menjaga alasan, urutan keputusan,
visual target, icon authority, serta next execution path tetap eksplisit di repository.

Jika percakapan/AI kehilangan konteks, baca dokumen ini sebelum membuat roadmap baru.

## Canonical repository state at lock creation

- Repository: `segeran-jiwa-pos-next`
- Branch: `work/cs06743-patch3-hardening`
- Pre-context-lock HEAD: `fbb90b3128189be82024d45a687e416f58e2347f`
- Working tree at start: clean
- Production automatic deployment: **DISABLED**
- Current execution phase: **POST-RC1 REFINEMENT CONVERGENCE**
- RC1 remains immutable and must not be rewritten.

## Immutable UAT RC1 behavioural baseline

- Tag: `uat-rc-20260921-1`
- Candidate commit: `e844f9b9ad07ca240e1ba4f72a39c6c7aefbb489`
- Cloudflare Preview: `https://5188a6b0.segeran-jiwa-pos-next.pages.dev`
- Pre-UAT regression: **91/91 JavaScript + 205/205 Python PASS**
- Isolated SQL UAT suite: **4/4 PASS**
- Browser smoke: **PASS** at 390x844
- Page errors: **0**
- Console errors: **0**
- Official Human UAT: **AWAITING_HUMAN_ACCEPTANCE**
- Final cutover: **BLOCKED until official UAT + final post-UAT regression pass**

RC1 is a behavioural/regression baseline. Runtime refinement work after this point must create
a new release candidate (RC2 or later); do not mutate or relabel RC1.

## Final hardening status already completed before refinement convergence

- P5A Operational Health: **LOCKED_REMOTE**
- P5B Offline Action Boundaries: **LOCKED_REMOTE**
- P5C Backup Health: **HEALTHY**
- P5C Isolated Restore Verification: **PASS**
- P5D / P5D2 Security Review: **CLEAR_OR_ACCEPTED / SAFE CHECKPOINT**
- Production automatic deployment remains **DISABLED**

Therefore the current task is not to rebuild these foundations.

## Why the four refinement boards exist

The four approved refinement boards did **not** originate as cosmetic redesign work.
They emerged after implementation and real-device UAT exposed a mismatch:

`backend/domain capability was already broad and safe, but the user-facing product was fragmented.`

Historical evidence:

1. UAT Wave 1 found `/jual` still using a placeholder even though checkout authority already existed.
2. UAT Wave 1 found Inventory/Purchase backend authority existed while operational UI/front doors were missing.
3. Those P1 blockers were fixed quickly so transactional UAT could continue.
4. Transactional flows then passed, proving the core engine.
5. Once the application could be exercised as a whole, the next gap became product coherence:
   - Home was still an engineering navigation grid.
   - different modules used different interaction patterns;
   - Settings was not a real Control Center;
   - Attention existed mainly as a global health banner, not an authority page;
   - Production backend existed without a final user-facing front door;
   - Inventory/Purchase/Finance were functionally rich but visually administrative/long-form;
   - the Segeran Jiwa icon family had not been integrated into runtime source;
   - revised Product / Variant / Recipe / Packaging semantics needed to be represented consistently.
6. Blueprint/business-rule discussion was refined around those findings.
7. Four refinement boards were then generated from that revised direction and approved as the final visual/UX direction.

Therefore:

> **Revised Blueprint = business/architecture authority.**  
> **Four Refinement Boards = visual/UX authority derived from that revised blueprint.**  
> **RC1 = behavioural/regression baseline.**

The next phase is convergence of implementation toward all three authorities, not a restart.

## Approved visual authority — Four Refinement Boards

### Board 01 — Application Shell & Dashboards

Authority for:

- Segeran Jiwa branded application shell;
- Owner Dashboard;
- Kasir Dashboard;
- structured Menu;
- mobile bottom navigation;
- desktop/sidebar adaptation;
- design-system density, cards, typography and status treatment.

Canonical mobile navigation:

`Beranda | Jual | Riwayat | Perhatian | Menu`

Important: any multi-outlet-looking sample copy on a board is visual affordance only unless
the revised business blueprint explicitly enables multi-outlet behaviour.

### Board 02 — Sales, Checkout & History

Authority for:

- product browsing/search/category flow;
- Favorite / Best Seller / All presentation;
- cart and quantity controls;
- checkout;
- Tunai;
- manual QRIS;
- Transfer;
- Hutang Pelanggan/Kasbon where authorized;
- one success authority;
- transaction history/detail;
- refund/correction presentation;
- responsive desktop sales layout.

The current `SalesScreen` is already materially functional and must be converged, not rewritten blindly.

### Board 03 — Inventory, Product/Recipe/Packaging, Purchase, Production & Shift

Authority for:

- Persediaan overview;
- Detail Barang;
- Product / Variant / Recipe / Packaging presentation;
- Purchase/Supplier/GRN;
- Production;
- Shift opening/active/closing;
- physical-count/reconciliation presentation;
- Gudang/Gerai stock visibility.

Cup/packaging control must remain reconciliation evidence over the single inventory engine,
never a second inventory authority.

### Board 04 — Settings, Finance, Users, Devices, Attention, Backup & Health

Authority for:

- Settings Home as Control Center;
- appearance/dashboard preferences;
- Finance front door;
- users and permissions;
- active/trusted devices;
- actionable Attention center;
- Backup & Restore;
- System Health;
- offline/sync states;
- diagnostics.

Health/backup states must always be evidence-backed. Never hard-code green/healthy states.

## Revised business-model authority that must survive visual refinement

### One inventory engine

All stock-changing activities converge on the same authoritative inventory movement model:

- sale;
- purchase receipt;
- production;
- transfer;
- refund/restoration where physically valid;
- shrinkage/waste/loss;
- opname/adjustment;
- opening balance or approved migration.

No screen may create a parallel stock writer.

### One finance engine

Money flows remain authoritative and linked to their source/destination movement.
Internal transfers are not income/expense.
Modal and Owner personal withdrawal retain their existing semantics.
No visual change may create a second money writer.

### Product is not the same thing as Stock Item

Final conceptual model:

```
SALE PRODUCT
  -> VARIANT / SIZE
       -> RECIPE COMPONENTS
       -> PACKAGING / DISCRETE COMPONENTS
       -> consumption stage
            SALE | PRODUCTION
       -> inventory movements through the existing engine
```

Examples:

```
Es Teh 16 oz
  - Teh
  - Gula (only if recipe uses it)
  - Cup 16
  - Tutup/Seal 16
  - Sedotan (only if configured)

Kopi Panas 10 oz
  - Kopi
  - Gula only if configured
  - Paper Cup 10
  - Tutup if configured
  - no straw unless explicitly mapped

Air Mineral
  - direct finished/direct stock item
  - no automatic cup/gula/sedotan
```

Rules:

- no global rule such as "all drinks use cup + sugar + straw";
- a variant may consume zero, one or many components;
- categories are presentation/filter metadata, not transaction logic;
- prepared-at-sale and pre-produced items must not double-consume stock;
- historical refund/correction must use sale-time snapshots, not current recipes;
- 100% discount does not erase physical consumption.

### Cup / packaging shift control

Cup is a normal Stock Item.

Physical shift usage:

`opening + inbound during shift - closing = physical usage`

Compare to:

`theoretical usage from transaction snapshots`

Variance may require a reason and, when stock correction is needed, must go through the canonical
opname/adjustment path.

## Current UI reality at the start of convergence

### Home

Current `HomeScreen` is primarily an engineering/permission-aware action grid.
It proves routes are reachable, but it is not yet the final Owner/Kasir dashboard.

### Sales

Current Sales V2 already includes substantial real functionality:

- search;
- category strip;
- product grid;
- stock blocking;
- cart;
- quantity adjustment;
- cash;
- quick cash;
- change display;
- manual QRIS;
- transfer;
- customer debt/Kasbon;
- notes;
- submit guard / idempotent operation handling.

This should be visually/domain-converged, not discarded.

### Inventory

Current Inventory UI is largely a searchable per-location administrative table.
Backend authority is substantially richer than the current presentation.

### Purchase

Purchase/Supplier/GRN/direct-buy capability exists and is reachable, but presentation remains
long-form/administrative compared with the approved Board 03 UX.

### Production

Backend authority, BOMs, production batches and permissions exist.
A final Production user-facing front door is not yet represented as a dedicated final screen.

### Finance

Finance is functionally rich but currently concentrated in a long-form screen.
Refinement should improve hierarchy without replacing the finance engine.

### Settings

There is no canonical final Settings Home / Control Center yet.
Settings behaviour is currently distributed across user/device/checkout/legacy-related surfaces.

### Attention

Global operational health/offline attention exists as a banner.
A full actionable `Perhatian` authority page is not yet the final product surface.

### Icons/assets

Runtime source currently does not yet contain the approved Segeran Jiwa icon family as an integrated
application asset registry.

## Icon authority

User-provided asset package:

`SEGERAN_JIWA_ICON_FAMILY_BATCH_02_WAVE_02_FIDELITY_LOCK_FILES(1).zip`

SHA-256 of the exact package received for this context lock:

`a536f31afe0e84c1a6e76f66008e99f6c934a53a660b15e3bba81ff1eb6bd50d`

The source ZIP remains an external authority package. C1-A has now ingested a controlled runtime subset
into `public/icons/segeran-jiwa/`; icon mapping/status remains governed by this package and the C1-A
checkpoint rather than being inferred from filenames.

### APPROVED icons in Wave 02 mapping

- notification
- product
- category
- warehouse
- customer
- employee
- account
- users
- active-device
- appearance
- store-identity
- printer
- security-sync
- activity
- diagnostics
- backup-restore
- sensitive-data
- logout

### Navigation icons in the package are REVIEW, not final for the revised IA

Package navigation baseline contains:

- home
- point-of-sale
- operations
- reports
- settings

All are marked `REVIEW`.

Do not blindly map this old five-item navigation to the revised final IA.
The final navigation authority is:

- Beranda
- Jual
- Riwayat
- Perhatian
- Menu

Navigation icon mapping must therefore be reconciled intentionally.

### Many operational icons remain TODO

Examples include:

- sales/cash/debt/restock/warning/inventory;
- cart/barcode/add/subtract/checkout;
- cash-payment/QRIS/transfer/credit-debt/receipt;
- stock/low-stock/out-of-stock/stock-adjust/warehouse-transfer;
- expense/shift/refund/employee-cash-advance;
- success/error/offline/sync/locked/permission-denied.

Implementation may use one consistent outline fallback for utility icons until custom icons are locked,
but semantic Segeran Jiwa approved icons must be preferred where available.

## Convergence workflow — current execution authority

Do **not** restart architecture discovery.
Do **not** re-run a full audit unless a contradictory source change appears.

### Phase C0 — Baseline lock

Keep these authorities explicit:

1. RC1 behavioural baseline;
2. revised blueprint/business rules;
3. four approved refinement boards;
4. Fidelity Lock icon package.

### Phase C1 — Icon + Design System + AppShell

First implementation target:

- ingest approved icon assets into a controlled registry;
- add Segeran Jiwa logo/brand asset through the same controlled design system;
- establish tokens for color, type, spacing, radii, shadows and semantic states;
- create reusable buttons/cards/badges/form fields;
- create mobile AppShell;
- create canonical bottom nav;
- create desktop/sidebar adaptation;
- preserve role/permission routing.

This is the **next concrete implementation action**.

### Phase C2 — Product / Variant / Recipe / Packaging convergence

Close the domain gap without replacing the inventory engine.

Target:

```
Product
  -> Variant
       -> Recipe components
       -> Packaging/discrete components
       -> sale-time snapshot
       -> authoritative inventory movement
```

### Phase C3 — Board 02 Sales convergence

Use existing Sales V2 as the base.
Add/refine only the real gaps required by the approved visual/domain authority.

### Phase C4 — Board 01 Dashboard convergence

Replace the engineering Home grid with role-aware Owner/Kasir dashboard and structured Menu
while preserving existing permissions and routes.

### Phase C5 — Board 03 Operations convergence

Converge Inventory, Detail Barang, Product/Recipe/Packaging, Purchase, Production and Shift
onto the shared design system.

### Phase C6 — Board 04 Control Center convergence

Build final Settings Home, Attention, Devices, Backup/Restore, Health and Diagnostics presentation
from existing evidence-backed authorities.

### Phase C7 — Secondary screen convergence

Bring Finance, Reports, History, Refund, Correction, Handover, Reconciliation and User Permission
screens into the same visual language without reimplementing their engines.

### Phase C8 — Full regression

Must re-prove:

- sale -> stock -> money -> audit/history;
- purchase -> receipt -> stock;
- production -> stock;
- transfer;
- refund/correction;
- shift expected/actual/variance;
- permissions;
- idempotency;
- offline boundaries;
- backup/restore health;
- security/cutover guards.

### Phase C9 — Create RC2

Any runtime/source refinement means RC1 stays immutable.
After full regression, create a new release candidate and a new Cloudflare Preview.

### Phase C10 — Batched Human UAT

Prefer grouped UAT instead of fragmented one-by-one prompting:

1. Shell / navigation / responsive;
2. Sales/payment;
3. Inventory/purchase/production;
4. Shift/finance;
5. Settings/attention/devices/health/backup/offline.

A P0/P1 finding means stop, patch, full regression, create next RC, rerun impacted UAT + smoke.

### Phase C11 — Final regression and cutover

Only after official human UAT passes:

- final post-UAT regression;
- cutover readiness check;
- explicit approval;
- production release gate.

## Non-negotiable guardrails

- Do not mutate or relabel RC1.
- Do not enable automatic Production deployment during convergence.
- Do not create a second inventory writer.
- Do not create a second finance writer.
- Do not hard-code cup/gula/sedotan rules by product name.
- Do not equate category with consumption logic.
- Do not restore prepared consumables blindly on refund.
- Do not show Backup/Health as green without evidence.
- Do not treat `navigator.onLine` as proof that backend health is good.
- Do not expose Owner-global finance to Cashier without explicit permission.
- Do not replace correction/reversal auditability with hard delete.
- Do not re-open already-cleared architecture merely because conversation context is missing;
  recover from this file first.

## Context recovery instruction for future sessions

Read, in this order:

1. `docs/checkpoints/REFINEMENT_CONVERGENCE_CONTEXT_LOCK_2026-09-22.md`
2. `docs/checkpoints/PROJECT_STATE.md`
3. `docs/uat/UAT_OFFICIAL_RC1_2026-09-21.md`
4. `docs/uat/UAT_BLOCKER_RECOVERY_2026-09-20.md`
5. `docs/checkpoints/RELEASE_MANIFEST.json`

Then inspect current Git HEAD/status before doing anything.

The expected next action after this context-lock commit is:

> **C1-A is complete. C2-A Product/Variant foundation is now complete in source. Proceed to C2-B sale execution + immutable consumption snapshot convergence.**

No new broad audit is required unless current source contradicts this lock.
