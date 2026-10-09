# C11-F13 — Browser Visual QA & Brand Asset Optimization

Date: 2026-10-09. Branch: `work/c11e-preuat-readiness-termux`.
Baseline: `b4c71e315194af11bd29aae9a68a53e61b489297`.
Device: Android Termux aarch64, Chromium 149/ChromeDriver 149, Vite local build preview.

## Scope and evidence status

This checkpoint verifies the **unauthenticated login screen**, asset loading, responsive viewport geometry, and protected-route redirects in a real local headless Chromium browser. Authenticated screens cannot be visually certified without a test session. Prior four design boards are reference mockups; they are NOT runtime screenshots.

## Authenticated-route boundary

With no signed-in browser session, navigating to each of `/laporan`, `/riwayat`, `/keuangan`, `/shift`, `/pengguna`, `/pembelian`, `/stok/kontrol`, and `/produk` resulted in `/login`, not an application module. This is expected access behavior, not proof that roles within an authenticated session are correct.

## Real browser viewport observations

ChromeDriver used `Emulation.setDeviceMetricsOverride`, then waited for client-side rendering and inspected DOM layout, document dimensions and the decoded logo. Screenshot filenames below are from the actual local built application and are stored in `docs/visual-evidence/c11f13/`.

| Viewport (CSS px) | Document dimensions | Card horizontal position | Card bottom | WebP decoded | Screenshot       |
| ----------------- | ------------------- | ------------------------ | ----------- | ------------ | ---------------- |
| 320×740           | 320×740             | x=10 width=300           | 688         | yes          | `login-320.png`  |
| 360×800           | 360×800             | x=10 width=340           | 718         | yes          | observed locally |
| 390×844           | 390×844             | x=10 width=370           | 740         | yes          | `login-390.png`  |
| 412×915           | 412×915             | x=10 width=392           | 775         | yes          | observed locally |
| 768×1024          | 768×1024            | x=164 width=440          | 851         | yes          | `login-768.png`  |
| 1280×800          | 1280×800            | x=420 width=440          | 739         | yes          | `login-1280.png` |

**Verified:** no horizontal document overflow at any of the six emulated viewport sizes, login card fits horizontally, full form fits vertically at the tested heights, and the browser loads the optimized `segeran-jiwa-logo-384.webp` image (naturalWidth 384) successfully.

**Not verified:** Android soft keyboard, touch gestures, device chrome/insets, authenticated Owner/Kasir layouts, cart overlay, interactive reports, Finance/Shift actions, permissions/device editor, purchase/inventory workflows, and actual production Cloudflare preview parity.

## Brand asset optimization

- Original `public/brand/segeran-jiwa-logo.png` is 1254×1254 and 1,346,625 bytes; left in place as PNG fallback, preserving the original brand resource.
- Added `public/brand/segeran-jiwa-logo-384.webp` (384×384, 8,060 bytes).
- Login, AppShell, and HomeScreen `img` elements prefer WebP through `srcSet` while retaining the old `src` fallback.
- Pusat Kontrol decorative CSS uses `image-set` with WebP and PNG types.
- Browser measurement shows WebP selected and decoded, avoiding dependence on assumptions from a first-frame headless screenshot.

## Safe boundaries and next work

- Only image delivery, shell/login/dashboard references, and decorative Pusat Kontrol CSS changed. No finance, stock, permissions, migrations, Supabase services, business data, or cutover settings changed.
- 3 new structural asset checks. Final Termux gates: Repo Guard PASS, Prettier PASS, ESLint PASS, TypeScript PASS, Vitest JavaScript 107/107 PASS, Python 501/501 PASS, Vite production build PASS, git diff check PASS. Existing Vite warnings remain about large main bundle and ineffective dynamic import.
- **LOGIN_BROWSER_PASS** for the six emulated sizes; **FULL_VISUAL_V_PASS=NO**, **HUMAN_UAT=OPEN**, **CUTOVER_READY=NO**.
- Next: authorized Owner/Kasir mobile screenshots/interaction checks for actual modules at 320, 360, 390, 412 px, tablet, desktop; fix observed issues and run real transaction/role UAT before final release lock.
