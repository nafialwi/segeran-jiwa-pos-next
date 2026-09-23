# PROJECT STATE — POST-RC1 REFINEMENT CONVERGENCE

## Canonical identity

- Workspace: Segeran Jiwa Next
- Product: Segeran Jiwa POS Next
- Branch: work/cs06743-patch3-hardening
- Current phase: **C8 FULL CROSS-DOMAIN REGRESSION — SAFEPOINT**
- Production automatic deployment: **DISABLED**
- Runtime release candidate baseline: **uat-rc-20260921-1**
- RC1 candidate commit: **e844f9b9ad07ca240e1ba4f72a39c6c7aefbb489**
- RC1 preview: **https://5188a6b0.segeran-jiwa-pos-next.pages.dev**
- Latest context authority: **docs/checkpoints/REFINEMENT_CONVERGENCE_CONTEXT_LOCK_2026-09-22.md**

## Current interpretation of progress

The historical weighted implementation roadmap reached 95% before P5 hardening.
P5A/P5B/P5C/P5D hardening has since been completed to safe/locked checkpoints and RC1 exists.

Do not use the old 95% number as a claim that the approved final product is visually complete.
Track these concerns separately:

- Core business engine: mature / substantially complete.
- Hardening: P5A-P5D safe/locked as documented.
- RC1 behavioural candidate: created and smoke-tested.
- Human official UAT: awaiting full acceptance.
- Visual/product convergence to revised blueprint + four approved refinement boards: **C1-C7 complete in source; C8 full cross-domain regression PASS; next is C9 RC2 Promotion & Preview Gate.**
- Final cutover: blocked until UAT and final post-UAT regression pass.

## Current verified state

- P5A Operational Health: LOCKED_REMOTE.
- P5B Offline Action Boundaries: LOCKED_REMOTE.
- P5C Backup Health: HEALTHY.
- P5C isolated restore verification: PASS.
- P5D/P5D2 security review: CLEAR_OR_ACCEPTED / safe checkpoint.
- Pre-UAT regression: PASS (91 JS / 205 Python).
- Isolated SQL UAT suite: 4/4 PASS.
- Cloudflare RC1 Preview: PASS.
- Browser smoke at 390x844: PASS.
- Browser smoke page errors: 0.
- Browser smoke console errors: 0.
- Production automatic deployment: DISABLED.
- Official Human UAT: AWAITING_HUMAN_ACCEPTANCE.
- Final cutover: BLOCKED.

## Why the project is now in refinement convergence

RC1 proved that the core application and hardening are materially functional, but real-device UAT
and source audit showed a product-coherence gap:

- Home entered convergence as an engineering/permission navigation grid; C4 now replaces it with role-aware Owner/Kasir dashboards.
- Sales V2 is much more polished than many other modules.
- Inventory/Purchase/Finance remain more administrative/long-form than the approved final UX.
- Production backend exists without a final dedicated product surface.
- Settings is not yet a canonical Control Center.
- Attention is not yet a full actionable authority page.
- Approved Segeran Jiwa icon assets are not yet integrated into runtime source.
- final Product/Variant/Recipe/Packaging semantics still need convergence with the revised blueprint.

The four approved refinement boards were created to solve this product-coherence gap.
They are not merely decorative references.

## Authority order for current convergence

1. **REFINEMENT_CONVERGENCE_CONTEXT_LOCK_2026-09-22.md**
2. Revised Blueprint / business-rule authority and decision records
3. Four approved Visual Refinement boards
4. RC1 behavioural baseline and UAT evidence
5. Fidelity Lock icon package authority
6. This PROJECT_STATE.md
7. RELEASE_MANIFEST.json and milestone checkpoint reports

If an older document says the next action is to create RC1 or begin pre-UAT work, that instruction
is historical and superseded by this current state.

## RC1 immutability

- Tag: uat-rc-20260921-1
- Commit: e844f9b9ad07ca240e1ba4f72a39c6c7aefbb489
- Preview: https://5188a6b0.segeran-jiwa-pos-next.pages.dev

RC1 must not be rewritten, retagged or silently changed.
Any runtime refinement after RC1 must lead to RC2 or later after full regression.

## Icon authority

External package supplied for refinement convergence:

- File: SEGERAN_JIWA_ICON_FAMILY_BATCH_02_WAVE_02_FIDELITY_LOCK_FILES(1).zip
- SHA-256: a536f31afe0e84c1a6e76f66008e99f6c934a53a660b15e3bba81ff1eb6bd50d
- Binary package is not yet committed to this repo.
- Approved Wave 02 semantic/system icons and navigation REVIEW/TODO status are documented in the context lock.

## C1-A safe checkpoint

C1-A is implemented and verified:

- controlled icon registry is in source;
- canonical mobile AppShell + bottom navigation exists;
- desktop sidebar adaptation exists;
- /perhatian and /menu front doors exist;
- existing route permissions remain in force;
- global P5A OperationalHealthBanner contract remains intact;
- canonical verify passes: **96/96 JS + 205/205 Python**, plus format/lint/typecheck/build/diff-check PASS.

See:
`docs/checkpoints/C1A_APP_SHELL_ICON_FOUNDATION_SAFEPOINT.md`

Known intentional deferment: exact approved Segeran Jiwa logo asset is not yet present in the canonical repo;
the shell uses a temporary explicit SJ monogram and does not claim final logo fidelity.

## C2-A safe checkpoint

C2 narrow contract audit and additive Product/Variant foundation are complete in source.

- new source migration: `20260922080000_c2a_product_variant_foundation.sql`;
- Product / Variant / SALE-stage component separation is defined;
- production-stage recipe authority remains BOM;
- current sale-enabled stock receives a DIRECT_STOCK compatibility backfill;
- additive `sales_catalog_v2` is defined;
- existing sale/inventory/finance writers are untouched;
- hosted database has **not** been mutated by C2-A;
- canonical verify: **96/96 JS + 212/212 Python PASS**, plus format/lint/typecheck/build/diff-check PASS.

See:
`docs/checkpoints/C2A_PRODUCT_VARIANT_FOUNDATION_SAFEPOINT.md`

## C2-B safe checkpoint

C2-B sale execution + immutable component snapshots are complete in source and have passed a real
transactional PostgreSQL rehearsal with rollback.

- additive `checkout_sale_v2`;
- immutable Product/Variant/component sale-time facts;
- one shared post-sale inventory/money engine;
- deterministic definitive stock gate;
- V2 replay proven non-duplicating;
- existing Refund/Correction proven to reverse the original V2 movement;
- legacy checkout fallback proven;
- hosted database remains unchanged after rollback;
- canonical verify: **96/96 JS + 220/220 Python PASS**, plus format/lint/typecheck/build/diff-check PASS.

See:
`docs/checkpoints/C2B_SALE_EXECUTION_SNAPSHOT_SAFEPOINT.md`

## C2-C safe checkpoint

C2-C downstream-reader convergence is complete in source and passed a real transactional PostgreSQL
rehearsal with rollback.

- unified private legacy/V2 sale-line read projection;
- V2-aware Transaction History items and product/variant search;
- Product/Sales reports group by sale Product/Variant identity rather than consumed inventory;
- Correction preview reads original canonical sale inventory movement;
- existing legacy rows remain readable through stock-item fallback;
- hosted database remains unchanged after rollback;
- canonical verify: **96/96 JS + 226/226 Python PASS**, plus format/lint/typecheck/build/diff-check PASS.

See:
`docs/checkpoints/C2C_READ_PROJECTION_CONVERGENCE_SAFEPOINT.md`

## C3-A safe checkpoint

C3-A Sales frontend contract convergence is complete in source.

- Sales catalog now uses `sales_catalog_v2`;
- cart identity is `variant_id`;
- checkout now uses `checkout_sale_v2` with `variant_id + quantity`;
- Product and Variant are both searchable and visibly represented;
- availability uses V2 capacity semantics;
- missing C2 schema fails closed and never silently falls back to Legacy checkout;
- online/payment/idempotency guards remain intact;
- hosted database and RC1 remain unchanged;
- canonical verify before checkpoint docs: **96/96 JS + 233/233 Python PASS**, plus format/lint/typecheck/build/diff-check PASS.

See:
`docs/checkpoints/C3A_SALES_FRONTEND_V2_CONTRACT_SAFEPOINT.md`

## C3-B safe checkpoint

C3-B Sales facts + Board 02 checkout convergence is complete in source.

- immutable discount authority with explicit `SALE_DISCOUNT` permission;
- cash tendered/change are persisted payment facts, not revenue;
- item notes are immutable sale-line facts;
- 100% discount consumes stock without creating a money movement;
- zero-total Refund/Correction are supported through original movement reversal;
- Product -> Variant chooser is present;
- checkout shows Subtotal / Diskon / Total;
- one `Pembayaran Berhasil` success authority is present;
- History exposes discount, line-note, tender/change facts;
- real transactional C2-A/C2-B/C2-C/C3-B PostgreSQL rehearsal: **PASS**, then rollback;
- hosted schema/data remain unchanged;
- canonical verify before checkpoint docs: **96/96 JS + 241/241 Python PASS**, plus format/lint/typecheck/build/diff-check PASS.

See:
`docs/checkpoints/C3B_SALES_FACTS_BOARD02_CHECKOUT_SAFEPOINT.md`

## C4 safe checkpoint

C4 Board 01 role-aware dashboard convergence is complete in source.

- Home is now role-aware Owner/Kasir dashboard rather than an engineering navigation grid;
- Owner KPIs reuse canonical SALES report and Owner-only money-balance authorities;
- Cashier reads only own/open-shift reconciliation facts and never global finance/report data;
- Owner-message surface is a truthful deferred state because no message authority exists yet;
- Attention remains evidence-bounded to the existing health authority;
- loading is card-level skeleton/error handling, not full-screen blocking;
- module navigation remains canonical in Menu and no operational route was removed;
- responsive mobile/desktop Board 01 hierarchy uses the C1 design system;
- C4 focused contract: **7/7 PASS**;
- full canonical verify before checkpoint docs: **96/96 JS + 248/248 Python PASS**, plus format/lint/typecheck/build/diff-check PASS.

See:
docs/checkpoints/C4_BOARD01_DASHBOARD_CONVERGENCE_SAFEPOINT.md

## C5-A safe checkpoint

C5-A Board 03 operations front-door convergence is complete in source.

- shared permission-aware Operations navigation;
- Persediaan converted from an admin table into card/detail-oriented operational UI;
- new Detail Barang route with authoritative saldo/location and movement history;
- new Product/Variant/Recipe/Packaging read surface;
- Product screen keeps SALE-stage components distinct from BOM Produksi;
- missing persistent C2 Product/Variant schema fails closed;
- new Produksi front door reuses existing create/post production RPCs and canonical inventory writer;
- Purchase and Shift are placed into the same operational navigation context;
- no new DB migration or business writer was introduced;
- full canonical verify before checkpoint docs: **96/96 JS + 257/257 Python PASS**, plus format/lint/typecheck/build/diff-check PASS.

See:
`docs/checkpoints/C5A_BOARD03_OPERATIONS_FRONT_DOOR_SAFEPOINT.md`

## C5-B safe checkpoint

C5-B Board 03 Purchase / Shift / Recipe Configuration convergence is complete in source.

- Purchase is grouped into Belanja Langsung / Pesanan Pemasok / Penerimaan Barang / Master Data;
- inventory Restock / Transfer / Stok Opname / Penyesuaian are first-class permission-bounded UI;
- all stock control mutations reuse existing P7/P8 canonical RPCs;
- packaging/cup is treated as an ordinary inventory Stock Item;
- Shift now has coherent Opening / Active / Reconciliation / Packaging / Closing presentation;
- theoretical packaging usage reads immutable sale-time component snapshots and fails closed until C2 is promoted;
- BOM draft/activate is exposed only through existing versioned BOM authority and PRODUCTION_MANAGE;
- Inventory Control child reads are scoped to bounded parent IDs to avoid read amplification;
- no new DB migration or second business writer was introduced;
- full canonical verify before checkpoint docs: **96/96 JS + 269/269 Python PASS**, plus format/lint/typecheck/build/diff-check PASS.

See:
`docs/checkpoints/C5B_BOARD03_PURCHASE_SHIFT_RECIPE_CONFIGURATION_SAFEPOINT.md`

## C8 safe checkpoint

C8 Full Cross-domain Regression is complete.

- canonical verify: **96/96 JS + 289/289 Python PASS**;
- C2/C3 migration + SQL regression payload: byte-for-byte unchanged from the real C3-B transactional rehearsal;
- fresh hosted RC1 authority probe: **31/31 PASS**;
- corrected hosted writer call-chain probe: **7/7 PASS**;
- C2/C3 tables remain intentionally unapplied persistently before RC2;
- fresh security state matches the classified P5D state with no new drift;
- official P5C backup-health validator recheck: **HEALTHY**;
- restore evidence remains **PASS**;
- cutover remains correctly fail-closed because Official UAT and final post-UAT regression are not PASS;
- Production automatic deployment remains disabled;
- no database mutation or deployment was performed by C8.

See:
docs/checkpoints/C8_FULL_CROSS_DOMAIN_REGRESSION_SAFEPOINT.md
docs/checkpoints/C8_REGRESSION_EVIDENCE.json

## C9 safe checkpoint

C9 RC2 Promotion & Preview Gate is complete through managed schema promotion and source-preview smoke.

- C2-A / C2-B / C2-C / C3-B managed migrations are present in hosted migration history in source order;
- immediate pre-promotion P5C backup-health recheck: **HEALTHY**;
- promoted Product/Variant/Sale component objects and checkout V2 authorities are present;
- expected C3-B sales/payment constraints and grants are present;
- no new anonymous application command exposure was introduced;
- Cloudflare Pages Preview for the converged runtime source passed unauthenticated Chrome 153 mobile-width smoke;
- RC1 remains immutable;
- Production automatic deployment remains disabled.

See:
`docs/checkpoints/C9_RC2_PROMOTION_PREVIEW_GATE.md`

## C10 RC2 finding / RC3 repair checkpoint

Authenticated RC2 Human UAT reached the real Owner shell and exposed one P1 authority defect on **Shift Saya**:

- observed error: `permission denied for table sales`;
- root cause: direct frontend read of protected `public.sales` solely to derive shift packaging usage;
- repair: new authenticated `public.shift_packaging_usage(uuid)` authority RPC reads immutable sale component snapshots server-side;
- direct client sales-table read removed from the packaging helper;
- hosted managed migration applied;
- new RPC denies anon execute and allows authenticated execute with pinned empty search_path;
- post-repair canonical verify: **96/96 JS + 293/293 Python PASS**, plus format/lint/typecheck/build/diff-check PASS;
- immutable RC3 tag: `uat-rc-20260922-3` at `3855e82`;
- RC3 Cloudflare Preview: `https://f70613ca.segeran-jiwa-pos-next.pages.dev`;
- GitHub verify, Cloudflare deploy, and unauthenticated mobile-width smoke: PASS;
- Production automatic deployment remains disabled.

See:
`docs/uat/UAT_OFFICIAL_RC3_2026-09-22.md`

## C10 RC4 finance + mobile-first checkpoint

Continuing authenticated Human UAT after RC3 found a second P1 authority defect on **Keuangan**:

- observed error: `permission denied for table sales`;
- repair: new Owner-only `public.finance_owner_overview()` server-side read projection;
- frontend finance overview no longer assembles protected finance/sales-derived facts through direct table reads;
- hosted managed migration applied; anon execute denied, authenticated execute allowed, empty search_path pinned;
- mobile-first shell/workflow hardening added;
- full post-repair canonical verify: **96/96 JS + 300/300 Python PASS**;
- immutable RC4 tag: `uat-rc-20260922-4` at `c86d4c0290261860e40df3501c09f4d1c4b63a14`;
- RC4 Preview: `https://608af457.segeran-jiwa-pos-next.pages.dev`;
- GitHub verify and Cloudflare Preview deploy: PASS;
- authenticated Shift recheck: PASS;
- authenticated Finance recheck: PASS;
- true Chrome responsive-device visual matrix at 400x686: PASS across the primary mobile routes;
- Production automatic deployment remains disabled.

See:
`docs/uat/UAT_OFFICIAL_RC4_2026-09-22.md`

## C10 RC4 final UAT checkpoint

Official Human UAT on immutable RC4 is complete.

- authenticated mobile-first route matrix: PASS;
- Shift authority blocker repair: PASS;
- Finance authority blocker repair: PASS;
- checkout sheet and payment-method presentation: PASS;
- pre-submit payment guards: PASS;
- browser OFFLINE state/banner and no-mutation-queue behavior: PASS;
- critical sale offline guard: PASS via real OFFLINE browser state plus executable require-online boundary before RPC;
- fresh security recheck: 10 RLS-without-policy / 0 direct grants, 4 known anon custom-auth warnings, 65 authenticated SECURITY DEFINER / 65 pinned search_path / 0 also-anon;
- final post-UAT regression: **96/96 JS + 300/300 Python PASS**, plus repo guard, format, lint, TypeScript, build, and diff-check;
- Production automatic deployment remains disabled.

Official UAT status: **PASS**.

## C11 visual refinement program

RC4 remains the immutable engineering/UAT baseline while C11 converges the four approved visual refinement boards on branch `work/c11-visual-convergence`.

Completed safe points:

- C11-A — canonical Legacy SVG icon family;
- C11-B — shell, supplied Segeran Jiwa brand logo, dashboard, navigation, menu;
- C11-C — POS, cart, checkout, success, transaction history;
- C11-D — Inventory, Product/Recipe, Purchase, Production, Shift, plus loading-efficiency hardening.

C11-D canonical verification: **96/96 JavaScript + 320/320 Python PASS**.
No C11 source change has been released to Production.

## NEXT ACTION

**Continue C11-E — Settings, Finance, Users/Devices, Attention, Backup/Health/Offline visual convergence.**

Keep RC4 immutable. Do not create RC5 and do not release Production until C11-E and C11-F mobile/desktop QA are complete.

## Cutover rule

Production remains fail-closed.

Required path:

Convergence source change
-> full regression
-> RC2 (or later)
-> new Cloudflare Preview
-> batched Human UAT
-> final post-UAT regression
-> cutover readiness
-> explicit approval
-> Production release gate
