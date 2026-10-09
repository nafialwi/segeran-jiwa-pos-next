# C11-F16 — Menu Discovery, Production Workflows, Owner Deep-Link Context

Date: 2026-10-09. Repository: `nafialwi/segeran-jiwa-pos-next`.
Branch: `work/c11e-preuat-readiness-termux`.
Baseline: `e0bc0100a1b869ded6086926bda89ca27bc95aea`.
Visual source: four user-approved UI reference boards (targets, not screenshots from authenticated runtime).

## User experience problems

- Menu listed all permission-eligible modules in long grouped sections and forced vertical scrolling to find a task.
- Production showed planning form, BOM list, and up to 50 batch cards together in one page, with technical introductory text.
- Pusat Kontrol linked to `/pengguna#permissions` and `/pengguna#devices`, but the newly separated Izin / Perangkat tabs in OwnerUsers did not respect the incoming hash on selection.

## Changes

### Menu

- Search-first control for permitted menu titles and descriptions, with Indonesian case-insensitive matching; search results are grouped by Operasional, Bisnis and Sistem.
- One group at a time by default, with horizontal category tabs and badge counts. Default Operasional remains selected initially.
- Mobile menu cards are shorter, with optional description truncated to one line; the card title, icon and link remain available.
- Existing permission checks, shift/draft verification and logout/switch confirmation logic are untouched.
- Business wording for customer debt in the finance menu changed to piutang.

### Owner: deep-link intent

- OwnerUsers now reads React Router location hash and opens the correct detail tab after a staff account is selected, retaining the Owner exception (devices only).
- The choice also follows hash changes while remaining on the same route.
- When a link to Izin / Perangkat arrives before user selection, a hint asks the Owner to choose a user; it does not select or alter a staff account automatically.
- No permission overrides, device admin or identity RPCs changed.

### Production

- One work panel at a time: Rencana, Batch, Resep Aktif.
- Batch list has Perlu Posting (default), Selesai and Semua filters, with local pagination of ten rows per view.
- Producing a new batch moves to the draft list; after posting, the screen shows the completed list, while leaving the original backend calls and validation unchanged.
- The backend overview still retrieves at most 50 recent batches; the interface explicitly states this limit and local paging **does not** imply complete history beyond that source window.
- Original `createProductionBatch` and `postProductionBatch` services, location selection, BOM source, action guards and all active forms remain in place.

## Remaining verification / risk

- Four source-based regression tests added for menu permission checks, deep-link selection, production actions, filters and scoped CSS.
- Browser screenshots of these screens with authorized Owner/Kasir data remain pending. A source-level pass is not a verified visual pass.
- On an authorized test account, verify menu search, category tabs, long Indonesian labels, keyboard, owner deep links and production tab switches at 320/360/390/412 px and tablet/desktop.
- Test production actions only against an approved nonproduction environment; this checkpoint **does not** execute production posts or simulate financial data as real.
- Verify role-sensitive menu cards and device management with real assigned permissions before UAT signoff.
- No Supabase schema, RPC, stock calculation, sale flow, production deployment or cutover manifest changed.
- `V-PASS=NO`, `HUMAN_UAT=OPEN`, `CUTOVER_READY=NO`.

## Quality gate

- Final Termux gate: repository guard PASS, Prettier PASS, ESLint PASS, TypeScript PASS, 107/107 JavaScript tests PASS, 513/513 Python tests PASS, production Vite build PASS, git diff check PASS. GitHub CI result must be verified after push.
- Current main JS artifact remains route-split (approximately 270.45 kB minified / 83.99 kB gzip).
