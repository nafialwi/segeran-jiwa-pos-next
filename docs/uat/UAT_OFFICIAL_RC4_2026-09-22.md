# Official UAT RC4 - 2026-09-22

Candidate tag: `uat-rc-20260922-4`
Candidate commit: `c86d4c0290261860e40df3501c09f4d1c4b63a14`
Preview: `https://608af457.segeran-jiwa-pos-next.pages.dev`

## Why RC4 exists

RC3 repaired the Shift packaging authority defect. Continuing authenticated UAT then exposed another P1 authority defect on **Keuangan**:

`permission denied for table sales`

The finance screen was still assembling its overview through multiple direct authenticated table/view reads. One of the sales-derived projections crossed a protected fact boundary.

RC4 introduces owner-only RPC `public.finance_owner_overview()` and routes the finance overview through that server-side authority. It also adds a mobile-first hardening layer for the shared shell and horizontally scrollable workflow navigation.

## Database and security evidence

- managed migration `c10_finance_overview_authority`: APPLIED
- `finance_owner_overview()` SECURITY DEFINER: YES
- pinned empty `search_path`: YES
- `anon` execute: DENIED
- `authenticated` execute: ALLOWED
- RPC requires active Owner authority and scopes all returned finance data to the active business
- prior `shift_packaging_usage(uuid)` repair remains active with anon execute denied
- P5C backup-health immediately before this migration: **HEALTHY**
- retained dump SHA-256 remains `75d9fa5d95d61403d6aa2f1b64f6ba3a9bd87a74b847c8587a25bea06de48ef3`

## Regression and deployment evidence

After the RC4 source repair:

- focused finance/mobile/migration regression: PASS
- JavaScript: **96/96 PASS**
- Python: **300/300 PASS**
- repo guard: PASS
- Prettier: PASS
- ESLint: PASS
- TypeScript: PASS
- production build: PASS
- diff-check: PASS
- GitHub canonical verify for `c86d4c0`: PASS
- Cloudflare Pages Preview deployment: PASS
- Production automatic deployment: **DISABLED**

RC4 is immutable at tag `uat-rc-20260922-4`.

## Authenticated RC4 findings

The exact RC4 Preview was exercised using the authorized Owner session.

### Authority blocker rechecks

- **Shift Saya**: PASS; the prior `permission denied for table sales` banner is gone.
- Shift active state and running cash KPIs load normally.
- **Keuangan**: PASS; the RC3 finance permission error is gone.
- Owner finance overview loads real ledger/account data.

No real shift close, refund, correction, finance posting, or production transaction was executed solely for UAT.

## Mobile-first authenticated visual UAT

Chrome DevTools responsive device emulation was used at **400 x 686 CSS pixels**. This is the authoritative mobile visual pass for RC4; it avoids the false result caused by merely shrinking the Windows Chrome window below its native minimum width.

Authenticated route matrix visually checked on RC4:

- Beranda
- Jual
- Riwayat
- Menu
- Shift Saya
- Persediaan
- Kontrol Stok
- Produk & Resep
- Pembelian & Pemasok
- Produksi
- Laporan
- Keuangan
- Rekonsiliasi Shift
- Approval Pengeluaran
- Pusat Kontrol
- Backup & Restore
- Kesehatan Sistem
- Offline & Sync

Observed result:

- five-item bottom navigation fits and remains usable;
- Owner role/header remains readable;
- KPI cards collapse appropriately for phone width;
- forms remain inside the viewport;
- workflow/tab rows remain horizontally scrollable instead of expanding the page;
- no blocking horizontal page overflow was observed at the 400px authenticated viewport;
- no P0/P1 visual defect was found in the route matrix;
- finance, shift, inventory, purchase, production, report, history, health, backup, and offline surfaces all rendered without authority-error banners.

Narrow 320/360 unauthenticated headless smoke was also captured. The authenticated sign-off in this run is the true 400px device-emulation pass; the source includes an explicit <=360px KPI fallback and viewport-hardening regression tests.

## Non-destructive interaction evidence

Sales mobile interaction was exercised without creating a server-side sale:

- available product selection: PASS
- local cart count changed from 0 to 1: PASS
- cart total changed to Rp 1.000: PASS
- fixed cart bar remains above the mobile bottom navigation: PASS

Transaction History:

- existing records load;
- six transactions were visible in the current search;
- Detail, Refund, and Correction actions remain reachable at mobile width.

Final financial mutation was intentionally not submitted solely to satisfy UAT.

## Remaining acceptance work

RC4 has cleared the two P1 authority defects found during RC2/RC3 and has completed the authenticated mobile visual route matrix.

Before final UAT PASS and cutover readiness, the remaining acceptance work is deliberately non-destructive:

1. checkout sheet/payment-method presentation and pre-submit guards;
2. explicit browser-offline behavior and proof that final critical submit is blocked with no silent replay;
3. final post-UAT canonical regression after the Human UAT evidence is closed.

Current status: **RC4_MOBILE_ROUTE_MATRIX_PASS_REMAINING_INTERACTION_UAT**.

Production remains fail-closed.
