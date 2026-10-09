# C11-F20 — Jual, Keranjang and Checkout UI evidence

**Date:** 2026-10-09

**Repository:** `nafialwi/segeran-jiwa-pos-next`

**Branch:** `work/c11e-preuat-readiness-termux`

**Baseline:** `def500e8378b06bb67388242698e426033ede588`

## Real component, simulated backend

This test runs the **actual** `SalesScreen` and `AppShell` in a dedicated Vite/Chromium browser harness. It substitutes synthetic data for active shift, catalog, customers, product media and checkout. The test is visibly labeled **DATA CONTOH · KHUSUS UJI UI · TANPA DATABASE · PEMBAYARAN DINONAKTIFKAN**. It is **not** an authenticated sale, server integration test or evidence of successful checkout.

- Test sources: `tests/browser-harness/f20/` on `127.0.0.1:4864` only.
- ChromeDriver connects on local port 9523.
- `checkoutSale()` in the fixture always throws; draft save/clear are no-ops and cannot persist a transaction. **The browser driver never clicks the payment button**.
- Production Vite and `src/main.tsx` do not reference any harness.
- No production database, real checkout, payment, RLS, migration or Cloudflare production deployment is touched.

## Browser observations

| Viewport CSS px | Catalog | Cart and total | Cash readiness UI | Variant picker | Document overflow |
| --------------- | ------- | -------------- | ----------------- | -------------- | ----------------- |
| 320×740         | PASS    | PASS           | PASS              | PASS           | none              |
| 360×800         | PASS    | PASS           | PASS              | PASS           | none              |
| 390×844         | PASS    | PASS           | PASS              | PASS           | none              |
| 412×915         | PASS    | PASS           | PASS              | PASS           | none              |
| 768×1024        | PASS    | PASS           | PASS              | PASS           | none              |
| 1280×800        | PASS    | PASS           | PASS              | PASS           | none              |

Fixture catalog includes five grouped sellable products with a two-option juice variant and one out-of-stock product. Test verifies the out-of-stock card is disabled, two products can be added to cart, cart subtotal displays **Rp 4.000**, the payment sheet and available methods render, and the Pay button is initially disabled until "Uang Pas" sets cash received to the exact total. It then confirms the _UI_ becomes enabled, without submitting or contacting a backend. Two product variants can also be selected from the modal.

**12 browser screenshots** (catalog / cart / variant at 320, 390, 768, and 1280 CSS px) are under `docs/visual-evidence/c11f20/`. The browser runner recorded `BROWSER_F20_PASS` and `BROWSER_CLOSED`.

## Reproduce

1. `node node_modules/vite/bin/vite.js --config tests/browser-harness/f20/vite.config.mjs`
2. `chromedriver --port=9523`
3. `python3 tests/browser-harness/f20/verify-browser.py`
4. Stop these two test-only processes afterward.

## Boundary and follow-up

- The reference image approved by the user is a **design target**, not measured parity with signed-in UI.
- The UI is responsive under Chrome's emulated viewports, **not yet verified** for physical Android keyboard, touch gestures and system insets.
- Production checkout, settlement, receipt, server-side idempotency, real stock deductions, low-balance failures and Owner/Cashier role UAT still require an authorized current-release candidate and test environment.
- Existing `CUTOVER_READY=NO` is retained. **Do not update the old release manifest or claim F20 UAT PASS.**

## Verification

Five F20 structural tests protect harness isolation and browser evidence. Final local gate: repository guard **PASS**, Prettier **PASS**, ESLint **PASS**, TypeScript **PASS**, Vitest **107/107 PASS**, Python **533/533 PASS**, Vite production build **PASS**, diff check **PASS**. GitHub CI must be checked after push.
