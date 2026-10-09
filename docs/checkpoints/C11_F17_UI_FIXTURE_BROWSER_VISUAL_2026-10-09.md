# C11-F17 — Visual QA with Isolated Browser Fixtures

Date: 2026-10-09. Repository: `nafialwi/segeran-jiwa-pos-next`.
Branch: `work/c11e-preuat-readiness-termux`.
Baseline: `32170daeeed0334b5e704fc2240e1ad2472f6640`.

## Scope

This checkpoint builds a **test-only** browser harness to run the real `MenuScreen`, `ProductionScreen` and `AppShell` components at multiple viewport sizes, without credentials or database requests. It creates reproducible visual evidence and exercises UI interactions, but is **not** authenticated Owner/Kasir UAT.

The prior F16 source-only verification could not establish visual correctness on phones. F17 fills part of that gap with a separate Vite test configuration and clearly marked example data. It does not alter application login, production services, RLS or financial/accounting behaviors.

## Reproducible harness

Location: `tests/browser-harness/f17/`.

From the repository root:

1. Run `node node_modules/vite/bin/vite.js --config tests/browser-harness/f17/vite.config.mjs` (binds loopback `127.0.0.1:4861`).
2. Start local ChromeDriver 149 on port 9520: `chromedriver --port=9520`.
3. Run `python3 tests/browser-harness/f17/verify-browser.py`. This opens Chromium, exercises the UI, and writes PNG evidence under `docs/visual-evidence/c11f17/`.
4. Stop both testing processes after the run.

This command uses a fixture-only import substitution. Real authentication, shift lookup, sales drafts and production API imports are replaced only under this dedicated test configuration. Both production posting functions in the fixture throw errors rather than creating or posting batches. The production Vite config and app entrypoint do **not** import the harness.

Screens display a prominent `DATA CONTOH · KHUSUS UJI UI · TANPA DATABASE` notice.

## Browser evidence

The local Chromium browser tested widths **320, 390, 412, 768 and 1280 CSS px**, with corresponding test heights 740, 844, 915, 1024 and 800 px.

Results:

- Menu Owner and Produksi render the real JSX/components (through stubbed auth/backend) and the genuine application navigation/header.
- No document horizontal overflow at all five tested widths.
- Menu category switch to `Bisnis` displays the authorized fixture choices, including Produksi and Keuangan for Owner.
- Menu search `Produksi` returns one entry at every tested width.
- Production Batch tab displays ten draft fixture batches per page, then six on page two.
- `Selesai` filter displays eight posted fixture batches.
- `Resep Aktif` tab renders one fixture BOM.
- A Kasir example role (at 390 px) omits Keuangan in the Bisnis category. This validates the **UI presentation of stubbed role permissions only**, not Supabase authorization.
- `BROWSER_F17_PASS` and `BROWSER_CLOSED` recorded by the reproducible browser runner.

Evidence folder includes 13 PNG captures for Owner Menu, Owner Production plan/batch views, and Kasir Menu. For example:

- `docs/visual-evidence/c11f17/menu-owner-320.png`
- `docs/visual-evidence/c11f17/menu-owner-390.png`
- `docs/visual-evidence/c11f17/produksi-owner-390.png`
- `docs/visual-evidence/c11f17/produksi-batch-owner-390.png`
- `docs/visual-evidence/c11f17/menu-kasir-390.png`

## Real change to production CSS

At 320 px, the menu-category scroller showed a conspicuous horizontal scrollbar track. F17 adds scoped scrollbar-hiding styles without disabling horizontal scrolling, and keyboard focus-visible outlines for Menu and Production work selector controls.

No business screen logic, services, DB schema, migrations, permission mappings or release settings were modified.

## Remaining boundaries

- **Not verified**: signed-in Owner/Kasir visual screenshots, live menu content with assigned permissions, phone keyboard/insets/touch handling, genuine backend production batch status, network failures or real posting actions.
- Do not run production posting or receiving against live accounts to validate this fixture.
- User-approved four UI boards remain design targets, not accepted deployed screenshots.
- `FULL_VISUAL_V_PASS=NO`, `HUMAN_UAT=OPEN`, `CUTOVER_READY=NO`.
- Live authenticated UAT and release manifest match are still required.

## Quality gate

- Five new source/fixture boundary tests were added.
- Final Termux regression: repository guard PASS, Prettier PASS, ESLint PASS, TypeScript PASS, Vitest JavaScript **107/107 PASS**, Python **518/518 PASS** (including 5 new F17 tests), production Vite build PASS, Git diff-check PASS.
- Vite main bundle remains route-split at approximately 270.45 kB minified / 83.99 kB gzip. All F17 fixture files are outside the production entrypoint.
- GitHub CI outcome must be checked after push; browser fixture tests passed on Chromium, but authenticated UAT remains open.
