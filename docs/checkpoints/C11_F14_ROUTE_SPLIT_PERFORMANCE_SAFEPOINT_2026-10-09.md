# C11-F14 — Mobile Route Loading Performance Checkpoint

Date: 2026-10-09. Branch: `work/c11e-preuat-readiness-termux`.
Starting commit: `2bc4e2fea4f04d22a47372f8e7bfed3b3bf023b5`.
Target: improve first-load responsiveness while preserving the C11 visual direction, navigation and authorization behavior.

## Why

The pre-F14 Vite production build contained a main JS asset of approximately 799.15 kB minified / 211.12 kB gzip. This shipped a large portion of the application's route code before the user navigated to a particular business workflow.

## Implemented

- `src/App.tsx`: 26 authenticated business and administration screens changed to React `lazy()` dynamic imports with explicit named-export mapping, preserving the exact existing route elements and `RequireAccess` authorization wrappers.
- `LoginScreen`, `OwnerUsersScreen`, and `AccessDeniedScreen` remain eagerly imported at this checkpoint (including compatibility with CS-03 Owner contract tests).
- `src/App.tsx`: add an accessible `Suspense` fallback for route-load waiting.
- `src/components/AppShell.tsx`: add a nearer `Suspense` boundary around the `Outlet`, keeping brand header, sidebar, and mobile bottom navigation visible while an authorized page loads.
- No database, Edge Function, payment, sale, stock, permissions policy, schema or production configuration changed.

## Before / after build artifact measurements

| Metric                    | Starting commit F13 |            F14 implementation |
| ------------------------- | ------------------: | ----------------------------: |
| Main JS minified          |           799.15 kB |                     269.21 kB |
| Main JS gzip              |           211.12 kB |                      83.72 kB |
| Main JS minified change   |                   — |                approx. -66.3% |
| Main JS gzip change       |                   — |                approx. -60.4% |
| Route split               |        Mostly eager |        26 lazy-loaded screens |
| Main Vite >500 kB warning |             Present | Cleared in the measured build |

**Important:** this is a measured reduction in the **main bundle**, not an equal reduction in total JavaScript needed throughout a complete POS session. Shared libraries are still shipped, including a separately emitted Supabase shared chunk (approx. 215.08 kB minified / 55.42 kB gzip). Navigation to each not-yet-loaded module now requires fetching its own chunk.

## Runtime browser validation

Real Android Termux Chromium 149 / ChromeDriver 149 used the built Vite preview (localhost), not a mockup:

- Login at viewport widths 320, 390, 768 CSS px: visible, no horizontal document overflow and no browser error banner in tests.
- Unauthenticated navigation to `/laporan`, `/keuangan`, and `/pembelian`: redirected to `/login`. No corresponding protected screen chunk was loaded in measured browser resources.
- Initial 320px Login browser resource transfer: main JS ~83.1 kB and shared Supabase ~55.3 kB in transfer-size measurements; other small JS resources also loaded.
- This checks an unsigned browser session only. It **does not verify authenticated navigation between lazy screens**; Owner/Kasir UAT remains required.

## Risk / boundaries

- Lazy-loaded screens require an online connection when opened for the first time; weak/offline connections may delay an unvisited screen. This does not add offline transaction support or change the policy of blocking online-only business writes.
- Authorization must remain server-enforced; keeping `RequireAccess` in router is a UI gate, not a substitute for Supabase RLS/RPC permission checks.
- Future UAT must verify rapid navigation, failed chunk retrieval on poor network, login-to-dashboard, cart and checkout, role-based menus and warm/cold module loads.
- Existing `cutover-readiness` gate must remain blocked until current manifest, human UAT and security checks are complete.
- `FULL_VISUAL_V_PASS=NO`, `HUMAN_UAT=OPEN`, `CUTOVER_READY=NO`.

## Automated regression

- Added `test_c11f14_lazy_route_loading.py` for dynamic imports, named export matching, protected-route boundaries and app-shell pending state.
- Final Termux gate: repo guard PASS, Prettier PASS, ESLint PASS, TypeScript PASS, 107/107 JavaScript tests PASS, 505/505 Python tests PASS, production Vite build PASS, and git diff check PASS. GitHub CI must be checked after push.
