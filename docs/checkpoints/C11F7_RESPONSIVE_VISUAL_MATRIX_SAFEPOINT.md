# C11-F7 — Responsive & Visual Matrix Safe Point

Date: 2026-09-24

## Purpose

C11-F7 hardens the shared layout system against horizontal overflow, crushed
controls, narrow action rows, tablet wrap failures, and inconsistent dialog
geometry before real-device UAT.

Baseline:

- branch: `work/c11-visual-convergence`
- baseline commit: `0fc5f50efdd66a49ce17fd15626d40c17438ea96`
- previous tag: `c11-f6-daily-interaction-cleanup-safepoint`
- database/schema: unchanged
- business authority: unchanged
- Production: untouched

The source matrix explicitly covers these reference viewport widths:

- 320 px
- 360 px
- 390 px
- 412 px
- 768 px
- 1024 px
- 1440 px

## Cross-screen overflow hardening

The final layout layer now bounds the root page, screen roots, panels, forms,
grid children, controls, and media with explicit `min-width: 0` /
`max-width: 100%` contracts.

This prevents long labels, status badges, form controls, identifiers, and grid
children from forcing the entire page wider than the viewport.

The root body is clipped against accidental page-level horizontal overflow.
Intentional horizontal content such as tables and workflow/tab strips keeps its
own local scroll container.

All current screen entry points are verified to use one of the bounded roots:

- `.shell`
- `.auth-page`
- `.center-card`

## Phone matrix

At widths below 760 px:

- screen shells remain inside a 16 px total outer gutter;
- common flex headers can wrap rather than compress text;
- action rows distribute available width safely;
- data-table wrappers keep local horizontal scrolling;
- navigation/tab/filter strips preserve touch momentum scrolling.

At 420 px and below:

- primary/secondary action buttons in shared action rows become full-width rows;
- auth card padding is reduced;
- role/status/payment chips can wrap instead of forcing overflow.

At 360 px and below:

- common cards/panels use slightly tighter horizontal padding;
- chip spacing and padding are reduced;
- existing one-column KPI/grid fallbacks remain intact.

## Tablet and desktop matrix

For the 760–959 px tablet band:

- complex panel headers and detail headers may wrap;
- action buttons retain bounded widths;
- modal dialog families use their desktop/modal geometry from 760 px upward.

At 960 px and above:

- normal desktop action-row sizing is restored;
- desktop tables, multi-column grids, and wider control surfaces remain the
  primary presentation.

Report behavior remains intentionally split:

- phone: compact mobile rows + drill-down;
- desktop/tablet presentation: structured table where already designed;
- table overflow stays local instead of expanding the whole page.

## Dialog and navigation consistency

The matrix keeps the current responsive behavior for:

- POS checkout sheet;
- searchable pickers;
- Product Master editor;
- shared Action Dialog;
- report drill-down dialog.

Mobile geometry remains sheet-oriented, while desktop geometry becomes centered
modal/panel where the existing component contract defines it.

Horizontal navigation groups remain contained and touch-scrollable:

- Operations navigation;
- Control Center navigation;
- secondary workflow navigation;
- Purchase tabs;
- Inventory Control tabs;
- Product Operations tabs;
- report period/filter strips.

## Regression contract

A new source-level responsive matrix suite verifies:

- reference phone/tablet/desktop widths;
- every screen uses a bounded root layout;
- required breakpoint families exist;
- root/form controls are overflow bounded;
- narrow action rows stack rather than crush labels;
- horizontal navigation strips remain intentionally scrollable;
- report mobile/desktop presentations remain separate;
- dialog families retain sheet/modal modes;
- JSX screen source contains no inline `minWidth` trap;
- bottom navigation continues to reserve safe-area space;
- C11-F7 adds no database migration.

Important boundary: this is the **source responsive matrix safe point**.
Real Android/iOS/browser-device behavior, keyboard overlays, browser chrome,
touch feel, and role-specific workflows remain F8 real-device UAT concerns.

## Verification

Focused C11-F7 responsive matrix:

- **11/11 PASS**

Canonical verification:

- JavaScript: **96/96 PASS**
- Python: **438/438 PASS**
- repository guard: **PASS**
- Prettier: **PASS**
- ESLint: **PASS**
- TypeScript: **PASS**
- production build: **PASS**
- `git diff --check`: **PASS**

The existing Vite `INEFFECTIVE_DYNAMIC_IMPORT` advisory for
`src/lib/supabase.ts` remains unchanged.

## Safety conclusion

C11-F7 is a layout/presentation safe point.

No sale, inventory, finance, shift, purchase, product, report, permission,
offline, database, or migration authority changes are introduced.

## Remaining C11 work

Next planned stage:

1. controlled F5 Product Media backend activation for the UAT environment;
2. C11-F8 — Owner/Kasir real-device UAT;
3. C11-F9 — final regression and blocker hardening;
4. C11 Final Lock / RC5 only after blockers are zero.
