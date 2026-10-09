# C11-F10 — Progressive Mobile UX for Reports & History

Date: 2026-10-09. Branch: `work/c11e-preuat-readiness-termux`.
Baseline: `ee0d52a311a73e60da8928888f0151bb2b645e99`.
Target: user-approved four UI reference boards; those illustrations are **targets**, not proof of installed visuals.

## Scope

Presentation-layer adjustments to `ReportsScreen.tsx`, `TransactionHistoryScreen.tsx`, `src/app.css` and regression checks. No changes to database, migrations, Supabase RPCs, permissions, sale writers, refund/correction execution, export source, or production configuration.

## Implemented — Reports

- Replace technical `READ MODEL` copy with brief business-oriented instruction.
- Keep quick periods (Today, 7 days, Month) visible; render two date inputs only for Custom.
- Keep search visible; reveal optional filter and sort chips with a clearly labeled toggle.
- Provide horizontal sections navigation; show first section initially, with `Semua bagian` available to show every original report section.
- Keep `report_run` authority, original report envelope, all summary/totals, complete per-row detail, original 20-row list pagination, and Excel export semantics intact.
- Indicate when optional filters remain active while collapsed.

## Implemented — Transaction History

- Preserve initially unfiltered server search and its 100-result limit; add quick period chips for All dates, Today, 7 days, and Custom.
- Keep invoice search always visible; place advanced dates/product/user/method/value/status controls in an expandable panel. Existing filter values persist when collapsed.
- Show ten results per screen with local pagination and return to list heading on page change.
- Preserve transaction detail, role-based refund/correction availability and confirmation flows unchanged.
- Explicitly show that the search returns at most 100 results.

## Safe Boundaries

- Search/filters within the report envelope remain presentation-only; Excel still exports the unfiltered complete report envelope.
- History quick presets request the same authorized `transaction_history_search` RPC with optional date parameters.
- No new financial numbers or graphs were manufactured to imitate reference mockups.
- History client pagination is **within the existing 100 fetched results**, not server-wide pagination.
- Recheck custom date editing, keyboard behavior, 320/360/390/412 px layouts, overflows, scroll position and role-gated controls in authenticated Owner/Kasir preview.

## Verification and Remaining Work

- Focused F10 regressions added (6 tests); two legacy wording/layout assertions updated to new intended UX behavior.
- Final native Termux regression: JavaScript/Vitest **107/107 PASS**; Python **485/485 PASS**, including **6** new F10 checks. Repo guard, Prettier, ESLint, TypeScript, production build, and Git diff-check **PASS**.
- Vite advisories remain: bundle above 500 kB and ineffective dynamic import for shared Supabase module. These are known performance concerns, not build errors.
- No browser-authenticated mobile screenshot in this checkpoint: visual acceptance `V-PASS` remains pending.
- Pending later phases: finance and shift restructuring; staff and operational screens; real-device validation, current production DB safeguards, final UAT, and release gates.
- `CUTOVER_READY=NO` until final UAT/release checks.
