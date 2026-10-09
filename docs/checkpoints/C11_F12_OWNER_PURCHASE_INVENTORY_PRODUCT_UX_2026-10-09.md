# C11-F12 — Pengguna, Pembelian, Kontrol Stok & Produk (UX Progressive)

Date: 2026-10-09. Branch: `work/c11e-preuat-readiness-termux`.
Baseline: `195df73ec0ac1c20885ed9658e23dc4e0282ce51`.
Design reference: the four user-approved UI boards. They are direction references, not verified screenshots of deployed UI.

## Goal

Shorten repetitive vertical scrolling on Android without removing business features or changing authority boundaries, Supabase calls, validation, financial movements or stock accounting.

## Pengguna & Izin

- Hide the staff creation form behind an explicit `Tambah Staf` button; close the form after successful creation.
- Show sensitive account-management actions only for the selected non-Owner account instead of every account card.
- Split selected-user detail into `Izin` and `Perangkat`; Owner accounts route straight to device information.
- Organize all original 20 individual operational permissions into five expandable groups: Kasir & Pembayaran; Barang & Operasional; Pelanggan & Staf; Riwayat & Laporan; Pengaturan.
- The original permission override effects (inherit, allow, deny) and server functions are unchanged. All 20 source-defined permissions are included exactly once.
- Device rename, revoke, remove, revoke-and-remove, identity admin, online guards and confirmations remain unchanged.

## Pembelian & Pemasok

- Retain existing four work tabs: Belanja Langsung, Pesanan Pemasok, Penerimaan Barang, Master Data.
- Inside Master Data, show either Tambah Pemasok or Tambah Barang at one time via a selector.
- Collapse the supplier payable detail list behind `Lihat Rincian Utang`; keep the aggregate payable balance visible.
- Keep receipt posting, direct purchase, purchase order, supplier master, stock item master and status checks unchanged.

## Kontrol Stok

- Retain the existing permission-limited Restock, Transfer, Stok Opname and Penyesuaian tabs.
- Simplify technical heading copy.
- Hide only the non-critical history of past adjustments by default, with a visible expandable control and history count. Restock approvals, transfer dispatch and selection of stock counts remain visible as before.
- Do not modify posting, inventory movement, count approvals or transfer logic.

## Produk & Resep

- On screens <=720 CSS px, show the searchable product list first. Selecting a product opens its detail, and a clear `Kembali ke Daftar Produk` button returns to the list.
- On desktop the existing list+detail layout remains.
- Existing product/media editing, variants, recipe, packaging, permissions, stock source and BOM editor are unchanged.

## Verification and Remaining Work

- Seven C11-F12 structural regression tests added, including exhaustive code mapping of all original operational permissions.
- Complete Python suite: 498 / 498 PASS.
- Final Termux verification: repo guard PASS; Prettier PASS; ESLint PASS; TypeScript PASS; JavaScript/Vitest **107/107 PASS**; Python **498/498 PASS** (including 7 F12 tests); Vite production build PASS; diff check PASS. Build advisories remain for the large main bundle and an ineffective shared Supabase dynamic import.
- GitHub CI result must be checked after push.
- Source-based tests do not replace authenticated visual/device UAT. Validate on real phones at 320/360/390/412 CSS px, tablet and desktop, including keyboard, scrolling, form drafts, permission save, device actions, receiving, inventory adjustments and product edit.
- No SQL migrations, RPC changes or production deployments.
- Release remains pending final UAT, cutover manifest lock, and security verification; `CUTOVER_READY=NO` is expected.
