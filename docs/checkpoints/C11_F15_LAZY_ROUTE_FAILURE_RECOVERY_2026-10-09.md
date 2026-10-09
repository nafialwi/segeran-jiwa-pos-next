# C11-F15 — Pemulihan Halaman Saat Jaringan Bermasalah

Date: 2026-10-09. Repository: `nafialwi/segeran-jiwa-pos-next`.
Branch: `work/c11e-preuat-readiness-termux`.
Baseline HEAD: `a3372f360333a0990a6f9a18005fbf745a42033b`.

## Scope

After F14 split 26 screens into lazy-loaded chunks, a failed network request for an unvisited route could reject the lazy import. React Suspense handles _waiting_ but not a rejected module promise. This safe-point adds an explicit user-driven recovery UI for those failures. It does not change any business service or authorization policy.

## Changes

- New `src/components/RouteErrorBoundary.tsx` catches a failed page render/import below the authenticated application shell and displays an Indonesian explanation, `Muat Ulang Halaman`, and `Kembali ke Beranda`.
- The error boundary wraps `Suspense` and `Outlet`, **inside** AppShell, so the existing top brand/header and bottom/sidebar navigation stay visible.
- `key={location.pathname}` resets the error state on navigation to another screen without automatically retrying transactions or stale writes.
- Recovery button reload is explicit and does not perform any finance, shift, payment, or stock action automatically.
- Scoped responsive `.route-load-error` CSS ensures full-width touch controls on small phones.
- A standalone developer-only browser harness under `tests/browser-harness` uses a deliberately rejected React lazy promise without credentials or backend requests.
- Added four targeted Python structural regression checks.

## Browser validation on Termux

Vite development server and Chromium 149 / ChromeDriver 149 were used to run `tests/browser-harness/f15-route-error.html` as a controlled simulation of a chunk-download failure.

| Width (CSS px) | Error fallback | Header + navigation retained | Horizontal overflow | Return to home |
| -------------- | -------------- | ---------------------------- | ------------------- | -------------- |
| 320            | PASS           | PASS                         | None                | PASS           |
| 390            | PASS           | PASS                         | None                | PASS           |
| 768            | PASS           | PASS                         | None                | PASS           |

Browser test verified: error title and both user actions present; clicking `Kembali ke Beranda` switches to safe content and clears error state. This is browser-tested _component behavior_, not verified real network throttling, not the production Cloudflare preview, and not an authenticated Owner/Kasir walkthrough.

## Release boundaries

- This is resilience for presentation/navigation only; no changes to Supabase, RLS, Edge Functions, sales/checkout, balances, inventory or release manifest.
- No user credentials or production transactions were accessed.
- Do not claim `V-PASS`, human UAT or final cutover success. Authenticated screenshots, menu flow, role tests and real network-loss recovery remain pending.
- Main bundle optimization from F14 is preserved; failed lazy chunks can now show an actionable UI instead of an uncaught error.
- `CUTOVER_READY=NO` until the established gates are satisfied.

## Automated verification

- Four new F15 regression checks added. Final Termux checks: repository guard PASS, Prettier PASS, ESLint PASS, TypeScript PASS, Vitest 107/107 PASS, Python 509/509 PASS, production build PASS, git diff check PASS. CI outcome must be checked after GitHub push.
- The production bundle continues to be split by route; the main JS artifact is approximately 269.95 kB minified / 83.87 kB gzip in this build.
