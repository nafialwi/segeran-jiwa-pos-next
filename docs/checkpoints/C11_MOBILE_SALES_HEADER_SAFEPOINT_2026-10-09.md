# C11 Mobile Sales Header — Safe Point (2026-10-09)

## Source and scope

- Repository: `nafialwi/segeran-jiwa-pos-next`
- Branch: `work/c11e-preuat-readiness-termux`
- Baseline HEAD: `960e2146be8b4d51497632fe66bcc278e3aac044`
- Visual target: user-approved Manus mockup (Gambar 2); the mockup is not evidence of deployed UI.
- Scope: Sales/Jual responsive CSS and source-based regression tests only; no business logic, Supabase, storage, sale, shift, or payment changes.

## Changes

- Correct mobile `.sales-v2-header` orientation to a compact single row at viewport widths up to 520 CSS px.
- Keep the shift status visible at widths up to 360 px instead of hiding it.
- Tune the small-screen title and shift chip geometry for 320–360 CSS px.
- Make the `Habis` regression assertion whitespace-tolerant; add targeted test for mobile header and visible shift state.
- Leave the in-cart badge and cart bar behavior unchanged pending authenticated real-device review.

## Completed verification

- Targeted Python Sales tests: 11/11 PASS.
- Complete Python suite: 479/479 PASS.
- Vitest JavaScript: 107/107 PASS.
- Repo guard, Prettier, ESLint, TypeScript, production Vite build, and `git diff --check`: PASS.
- On native Termux, direct `node node_modules/.../*.js` entry points were used for Node CLI tools to avoid the absent `/usr/bin/env` interpreter in standard shims.
- Build warnings remain: a large JavaScript bundle and an ineffective dynamic import; they are not new release-blocking errors.

## Pending acceptance / release boundary

- Real Android viewport screenshots and interaction checks (320, 360, 390–412 px); Owner and Kasir sessions.
- Verify nonempty cart badge, empty-cart disabled state, keyboard, sticky cart, bottom navigation and no clipping in real browser.
- Product photography in the approved mockup requires actual product media; do not treat mockup photos as existing backend images.
- Human UAT, ambiguous checkout retry/idempotency, current database security audit and final cutover gates remain pending.
- `V-PASS` NOT YET; `C11 FINAL LOCK` NOT YET; `CUTOVER_READY=NO` expected.
- Production automatic deployment remains disabled. No production deployment was performed.
