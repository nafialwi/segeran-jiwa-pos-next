# C11-F19 — Keuangan and Shift Saya browser UI verification (isolated fixtures)

Date: 2026-10-09. Repository: `nafialwi/segeran-jiwa-pos-next`.
Branch: `work/c11e-preuat-readiness-termux`.
Baseline: `619f3151f9e97878c014389281be8612d0cdefb2`.

## Scope and accuracy

Runs the **actual React FinanceScreen, ShiftManagementScreen and AppShell components** using isolated fixture modules; NOT a logged-in Owner/Kasir test, not backend reconciliation, and not production data. Every visual fixture page is labeled `DATA CONTOH · KHUSUS UJI UI · TANPA DATABASE`.

The F19 harness in `tests/browser-harness/f19/` uses a dedicated loopback Vite test config and mocks authorization, shift/finance reads, and inventory operations. All finance writes, `openShift`, `closeShift`, `postShiftExpense`, packaging posting and inventory posting are disabled: test stub functions throw errors, rather than performing live database writes. The real production Vite entrypoint does not import this harness.

## Browser evidence

Chromium 149 / ChromeDriver 149 on Android Termux exercised widths 320, 390, 412, 768 and 1280 CSS px with heights 740, 844, 915, 1024 and 800 px.

- **Keuangan:** six overview balance/debt KPI cards (fixture amounts only), nine workflow choices (Saldo, Pindah Uang, QRIS, Piutang, Utang Pemasok, Rekonsiliasi, Kasbon, Owner, Approval). Switching from Saldo to Piutang and then Pindah Uang rendered only the selected workflow panel.
- **Shift Saya:** four KPI cards, active shift header, and six workflow choices under fixture Owner authorization. Kas Shift and Tutup Shift could be opened without overflow, preserving actual validation and button components. No close-shift button was submitted.
- **Fixture Kasir (390 px):** five workflow tabs; Pengeluaran was absent because the fixture role lacks `EXPENSE_SHIFT_CREATE`. This verifies conditional UI display only; it does NOT prove live RLS/role enforcement.
- All five tested widths had no document horizontal overflow in both screens.
- After inspecting the initial 320 px Keuangan screenshot, a small scoped CSS refinement reinstated **two KPI columns** instead of a long single column at widths up to 360 px, reduced card size and hid a decorative hero icon. The browser runner confirms two columns at 320 px and no horizontal overflow.

The successful browser run recorded `BROWSER_F19_PASS` and `BROWSER_CLOSED`. Evidence is stored in `docs/visual-evidence/c11f19/`, including owner finance summary/transfer and owner shift overview/closing at 320, 390, 768 and 1280 CSS px, plus fixture Kasir Shift at 390 px (17 captures total).

## Reproduction

1. Run `node node_modules/vite/bin/vite.js --config tests/browser-harness/f19/vite.config.mjs` from repository root (127.0.0.1:4863).
2. Run `chromedriver --port=9522` locally.
3. Run `python3 tests/browser-harness/f19/verify-browser.py`.
4. Stop both test-only processes after completion.

## Non-negotiable remaining work

- Human visual signoff with actual logged-in Owner and Kasir, Cloudflare preview at current commit, phone soft keyboard and swipes.
- Verify real finance and shift read data, server role boundaries, actual reconciliation/packaging, and full transaction UAT against authorized nonproduction data.
- Original four approved UI boards are visual targets; fixture screenshots are not accepted as authenticated proof.
- No SQL, Supabase RLS/RPC, stock/payment rules or production deployment were modified.
- `FULL_VISUAL_V_PASS=NO`, `HUMAN_UAT=OPEN`, `CUTOVER_READY=NO`.

## Quality gate

Five new F19 source-based tests validate isolation, denied mutation stubs, responsive/browser assertions and fixture evidence. Final Termux checks: repository guard PASS, Prettier PASS, ESLint PASS, TypeScript PASS, Vitest JavaScript **107/107 PASS**, Python **528/528 PASS**, Vite production build PASS, git diff check PASS. Main production bundle remains route-split (~270.45 kB minified / 84.00 kB gzip). GitHub CI must be checked after push.
