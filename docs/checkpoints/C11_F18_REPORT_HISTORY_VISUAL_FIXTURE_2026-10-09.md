# C11-F18 — Reports and Transaction History Responsive Browser Verification

Date: 2026-10-09. Repository `nafialwi/segeran-jiwa-pos-next`.
Branch: `work/c11e-preuat-readiness-termux`.
Baseline commit: `fff157b2e716e529cb9061e57b1527b9c972aa98`.

## Scope and honesty boundary

This checkpoint extends the previously proven F17 testing technique to the **real ReportsScreen and TransactionHistoryScreen components**, rendered with a separate, isolated visual fixture. **It does not authenticate real Owner/Kasir accounts**, call Supabase, modify financial data, or claim final UAT completion. The initial requested F18 authenticated visual review remains blocked until an authorized session is available.

All fixture pages prominently display: `DATA CONTOH · KHUSUS UJI UI · TANPA DATABASE`.

## Verified local UI

ChromeDriver / headless Chromium on Termux exercised:

| CSS viewport | Laporan | Riwayat |
| ------------ | ------- | ------- |
| 320×740      | PASS    | PASS    |
| 390×844      | PASS    | PASS    |
| 412×915      | PASS    | PASS    |
| 768×1024     | PASS    | PASS    |
| 1280×800     | PASS    | PASS    |

At all five widths:

- Actual ReportsScreen and TransactionHistoryScreen loaded with AppShell header and navigation and no document horizontal overflow.
- `Tampilkan Laporan` displayed three sample KPI cards, a first section containing 20 sample rows, and section-switch controls. `Semua bagian` displayed the additional report section. Advanced report filters opened.
- Transaction history showed 24 synthetic records, 10 on the first page and 10 on the second; second-page indicator displayed 11–20. `Filter Lanjutan` opened and invoice search for `CONTOH-0001` returned a single example transaction.
- Horizontal period/section tabs remained swipeable. At compact widths the computed scrollbar track is now hidden.
- No backend report export, financial write, refund, correction, stock update or real transaction operation occurred.

## Actual refinement

Inspecting the before screenshots showed conspicuous scrollbar tracks under the Riwayat period selector and Laporan section controls, particularly at 320/390 CSS px. The only production UI change in this phase is scoped CSS that hides those tracks while retaining `overflow-x:auto` from earlier stages, and adds keyboard `:focus-visible` outlines.

## Reproducible test setup

Test-only files in `tests/browser-harness/f18/`:

1. Start `node node_modules/vite/bin/vite.js --config tests/browser-harness/f18/vite.config.mjs` on loopback port 4862.
2. Start `chromedriver --port=9521`.
3. Run `python3 tests/browser-harness/f18/verify-browser.py`.
4. Stop both processes when done.

The special Vite config redirects source imports for authentication, reports, history and Excel export to fixture-only modules. Refund, correction and Excel functions throw an error if called; they never contact a service. The production Vite config and app entrypoint do not reference this harness.

The browser runner saves eight PNG screenshots under `docs/visual-evidence/c11f18/`, covering Laporan and Riwayat at 320, 390, 768 and 1280 CSS px.

## Remaining concerns

- Screenshots are **from the original React UI with synthetic values**, not screenshots of an actual logged-in production account.
- Validate real Owner and Kasir permissions, actual report data shapes, all report types, financial integrity, refund/correction confirmation flows and receipt behavior in an approved nonproduction or expressly authorized environment.
- Device keyboard, touch gestures and poor-network experience require manual verification on Android.
- Keuangan and Shift authenticated visual testing remains outstanding and is the suggested next focus.
- No Supabase changes, migrations, deployment changes or cutover manifest changes in this checkpoint.
- `FULL_VISUAL_V_PASS=NO`, `HUMAN_UAT=OPEN`, `CUTOVER_READY=NO`.

## Quality gate

Five new source-level tests cover harness isolation, disabled writes, responsive browser coverage, and CSS refinement. Final local quality gate: repository guard PASS, Prettier PASS, ESLint PASS, TypeScript PASS, Vitest JavaScript **107/107 PASS**, Python **523/523 PASS**, Vite production build PASS, git diff check PASS. Main production JS remains route-split at approximately 270.45 kB minified / 84.00 kB gzip. GitHub CI status must be checked after push.
