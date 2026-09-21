# C1-A AppShell & Icon Foundation — SAFEPOINT

Date: 2026-09-22

Branch: `work/cs06743-patch3-hardening`

## Outcome

C1-A establishes the first runtime convergence layer after immutable UAT RC1:

- controlled Segeran Jiwa icon registry;
- canonical responsive AppShell;
- mobile bottom navigation;
- desktop sidebar from the same navigation authority;
- first-class `/perhatian` and `/menu` front doors;
- shared C1 design tokens and shell styles;
- no business-writer, database, migration, finance, inventory, payment, shift, backup, or security authority changes.

This checkpoint is a **safe foundation**, not final visual completion of the four refinement boards.

## Baselines preserved

- RC1 tag: `uat-rc-20260921-1`
- RC1 candidate commit: `e844f9b9ad07ca240e1ba4f72a39c6c7aefbb489`
- RC1 Preview: `https://5188a6b0.segeran-jiwa-pos-next.pages.dev`
- Production automatic deployment: **DISABLED**
- RC1 was not rewritten, retagged, or redeployed.

## Icon authority ingested

External source package:

`SEGERAN_JIWA_ICON_FAMILY_BATCH_02_WAVE_02_FIDELITY_LOCK_FILES(1).zip`

Source package SHA-256:

`a536f31afe0e84c1a6e76f66008e99f6c934a53a660b15e3bba81ff1eb6bd50d`

A controlled subset is now present under:

`public/icons/segeran-jiwa/`

C1 registry explicitly preserves icon-status authority:

### APPROVED semantic/system icons

- activity
- notification
- warehouse
- product
- users
- account
- logout
- diagnostics
- security-sync
- backup-restore

### REVIEW navigation icons

- home
- point-of-sale
- settings

These REVIEW icons are allowed as provisional shell assets only. They are not silently promoted to APPROVED.

The final information architecture remains:

`Beranda | Jual | Riwayat | Perhatian | Menu`

The older package navigation labels do not override this revised IA.

## Runtime source added

### `src/ui/iconRegistry.ts`

Single mapping authority for icon name, status, outline path, and optional active path.

### `src/ui/Icon.tsx`

Reusable current-color icon renderer using controlled asset paths.

### `src/navigation/appNavigation.ts`

Canonical primary navigation authority.

Permission-aware behavior:

- Beranda: always visible for authenticated active user;
- Jual: requires `SALE_EXECUTE`;
- Riwayat: requires `HISTORY_OWN` or `HISTORY_ALL`;
- Perhatian: authenticated surface;
- Menu: authenticated surface.

Secondary operational routes intentionally resolve to the Menu active state.

### `src/components/AppShell.tsx`

Responsive shell foundation:

- mobile branded header;
- mobile bottom navigation;
- desktop sidebar;
- authenticated user identity summary;
- a single `Outlet` route surface.

The exact approved Segeran Jiwa logo asset is **not yet available in the canonical repo**.
C1-A therefore uses an explicit temporary `SJ` monogram and does not claim logo-fidelity completion.

### `src/screens/AttentionScreen.tsx`

Creates the canonical `/perhatian` front door without fabricating backend health.

Current scope is intentionally conservative:

- device online/offline attention;
- explicit warning that browser connectivity is not proof of database/backend health.

Broader business attention aggregation remains C6 work.

### `src/screens/MenuScreen.tsx`

Replaces dependence on the Home engineering link grid for secondary navigation.

Groups permission-aware modules into:

- Operasional;
- Bisnis;
- Sistem.

Existing routes and permission guards remain authoritative.

### `src/App.tsx`

Moves authenticated pages under the new AppShell while preserving all existing route guards.

`OperationalHealthBanner` remains global at App level to preserve the locked P5A contract.

### `src/app.css`

Adds shared C1 design tokens and responsive shell primitives.

Important mobile compatibility:

- fixed bottom navigation accounts for safe-area inset;
- Sales V2 cart bar is lifted above the bottom navigation;
- desktop shell switches to sidebar at 960px.

## Test added

`tests/c1-app-shell.test.ts`

Verifies:

1. canonical primary order for an authorized operator:
   `Beranda, Jual, Riwayat, Perhatian, Menu`;
2. permission-gated primary entries are not exposed to restricted users;
3. secondary routes resolve to Menu active state;
4. APPROVED vs REVIEW icon authority remains explicit;
5. active icon variants resolve without changing semantic icon paths.

## Regression encountered and corrected

The first full Python regression found one P5A static-contract failure because
`OperationalHealthBanner` had initially been moved from `App.tsx` into `AppShell.tsx`.

Disposition:

- no weakening of the P5A test;
- global health banner restored at App level;
- duplicate shell rendering removed;
- targeted P5A regression passed;
- full Python regression then passed.

This preserves the earlier hardening contract instead of modifying tests to accept a weaker implementation.

## Verification evidence

C1 targeted tests:

- `tests/c1-app-shell.test.ts`: **5/5 PASS**
- P5A targeted Python tests: **3/3 PASS**

Full canonical verification after the correction:

- format: **PASS**
- lint: **PASS**
- TypeScript typecheck: **PASS**
- JavaScript: **96/96 PASS**
- Python: **205/205 PASS**
- production build: **PASS**
- `git diff --check`: **PASS**

Build warning retained as non-blocking existing bundling observation:

- `src/lib/supabase.ts` is both dynamically and statically imported, so the dynamic import does not split it into a separate chunk.

No integrity test was bypassed or edited to obtain the PASS.

## Explicitly not completed in C1-A

- exact Segeran Jiwa logo integration;
- Owner Dashboard final Board 01 composition;
- Kasir Dashboard final Board 01 composition;
- full Settings Control Center;
- full Attention business aggregation;
- Product/Variant/Recipe/Packaging convergence;
- Production final front door;
- final custom navigation-icon fidelity approval;
- RC2 creation;
- Cloudflare refinement Preview;
- Human UAT for the refined shell.

## Production impact

**NONE.**

- no production deployment;
- no Supabase schema/data mutation;
- no migration;
- no business ledger change;
- no inventory writer change;
- no finance writer change;
- no RC1 mutation.

## Next execution phase

Proceed to **C2 — Product / Variant / Recipe / Packaging convergence design-to-source work**,
while keeping C1-A shell stable.

Before any C2 database/domain mutation, perform a narrow contract audit specifically around:

- current `stock_items` sale semantics;
- current BOM semantics;
- sale posting/inventory consumption;
- refund/correction historical facts;
- migration compatibility.

Do not restart broad project discovery.
