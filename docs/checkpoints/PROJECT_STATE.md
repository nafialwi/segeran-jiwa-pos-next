# PROJECT STATE — POST-RC1 REFINEMENT CONVERGENCE

## Canonical identity

- Workspace: Segeran Jiwa Next
- Product: Segeran Jiwa POS Next
- Branch: work/cs06743-patch3-hardening
- Current phase: **C2-C V2 READ PROJECTION CONVERGENCE — SAFEPOINT**
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
- Visual/product convergence to revised blueprint + four approved refinement boards: **C1-A shell/icon + C2-A Product/Variant + C2-B sale execution/snapshot + C2-C V2 readers complete in source; Sales frontend/visual convergence still in progress.**
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

- Home is still primarily an engineering/permission navigation grid.
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

## NEXT ACTION

**Begin C3-A — Sales Frontend V2 Contract Convergence.**

Move the frontend contract from stock-item sale identity to Product/Variant identity while preserving
all existing cashier/payment/idempotency/offline safety behavior.

Do not persistently apply C2 migrations or deploy a new Preview until a dedicated RC2
migration/deployment gate is reached.

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
