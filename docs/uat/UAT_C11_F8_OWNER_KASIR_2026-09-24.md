# C11-F8 — Owner/Kasir Real-Device UAT

Date prepared: 2026-09-24

Status: **READY FOR HUMAN UAT — NOT YET PASS**

Candidate source:

- branch: `work/c11-visual-convergence`
- F7 source commit: `6212c3ebe1039dcb66a6c7f0e3e8077bbd65acbc`
- F7 tag: `c11-f7-responsive-visual-matrix-safepoint`
- commit preview: `https://f6879673.segeran-jiwa-pos-next.pages.dev`
- branch preview:
  `https://work-c11-visual-convergence.segeran-jiwa-pos-next.pages.dev`

Backend readiness:

- F0A Product Master: active;
- F5 Product Media: active on shared Supabase backend;
- Product Media capability/read smoke: PASS;
- Product Media writer rolled-back smoke: PASS;
- no test product image persisted by backend smoke.

## UAT principle

F8 is a human usability/behavior check, not another source-development phase.

A finding should be recorded only when it is observable on the exact candidate.
Do not redesign an area during UAT unless the finding blocks or materially harms
daily use.

Classify findings as:

- P0 — loss/corruption/security/business-authority failure;
- P1 — core daily workflow cannot be completed;
- P2 — workflow works but is confusing, slow, cramped, or materially awkward;
- P3 — cosmetic polish only.

Final F8 PASS requires P0 = 0 and P1 = 0.

## Device matrix

Minimum real-device pass:

1. Android phone around 360–412 CSS px — Owner;
2. Android phone around 360–412 CSS px — Kasir;
3. desktop browser — Owner.

When practical, also check a narrow 320 px responsive viewport and a tablet /
large-phone viewport.

For each route verify:

- no whole-page horizontal overflow;
- bottom navigation is not covered;
- keyboard does not permanently hide the action being edited;
- buttons are reachable and labels readable;
- tab/chip strips scroll intentionally rather than stretching the page;
- after Back/Close, the user returns to a sensible position;
- loading/error/success states are understandable.

## Owner — Product Media acceptance

Use one existing product that has a real photo available.

1. Open Menu > Produk & Resep.
2. Select the product.
3. Open Kelola Produk.
4. Confirm **Foto Produk / Gambar di Katalog Jual** is active.
5. Tap **Pilih Foto**.
6. Choose JPG/PNG/WebP.
7. Wait for the success message.
8. Close Product Master.
9. Confirm thumbnail appears in Produk & Resep.
10. Open Jual and confirm the same product card uses the photo.
11. Re-open Product Master and use **Ganti Foto** with a second image.
12. Confirm the new photo replaces the old photo in both surfaces.
13. Use **Hapus Foto**.
14. Confirm both surfaces safely return to the placeholder.
15. Upload the intended final photo again if the product should retain a photo.

PASS criteria:

- no manual resize/compression needed;
- upload does not block unrelated product editing;
- no broken-image icon is left behind;
- Jual remains usable while images load;
- replacing/removing a photo never changes product price, stock, recipe, or sale
  availability.

## Owner — primary daily route matrix

Check these routes in normal operating order:

- Beranda;
- Jual;
- Riwayat;
- Laporan;
- Menu;
- Shift Saya;
- Persediaan;
- Kontrol Stok;
- Produk & Resep;
- Pembelian & Pemasok;
- Produksi;
- Keuangan;
- Rekonsiliasi Shift;
- Approval Pengeluaran;
- Pengguna & Perangkat;
- Pusat Kontrol;
- Backup & Restore;
- Kesehatan Sistem;
- Offline & Sync.

Specific F6/F7 checks:

- destructive confirmations use Segeran Jiwa in-app dialog, not browser popup;
- password reset uses the in-app password field;
- numeric inputs bring a numeric/decimal keyboard appropriate to the field;
- action rows stack cleanly on narrow phone width;
- long identifiers/statuses do not expand the whole page;
- modal/bottom-sheet close behavior is predictable.

## Owner — Laporan acceptance

Run at least Penjualan, Produk, Persediaan, Shift, Purchase, and Finance reports
that the Owner account is authorized to view.

Check:

- Hari ini / 7 hari / Bulan ini / Custom presets;
- search/filter/sort;
- 20-row pagination when enough data exists;
- compact rows communicate identity before Detail is opened;
- Detail exposes the complete report row;
- Product rows identify the product, not an abstract status;
- Finance money flow identifies source/reason/reference rather than repeating only
  INCOME;
- Piutang Pelanggan identifies the customer and outstanding balance;
- report screen has no page-level horizontal overflow;
- Excel export remains separate from current page/filter presentation.

## Kasir — daily workflow matrix

Log in with a Kasir account on the phone.

Verify:

- Beranda shows cashier-appropriate content;
- Jual opens with active-shift truth;
- product search/category filtering works;
- 2/3/4-column density setting remains usable;
- product photos, when present, are presentation-only and do not delay first
  catalog availability;
- add item, increase/decrease quantity, remove item;
- open checkout sheet;
- Tunai / QRIS / Transfer / Kasbon choices remain visible when permitted;
- changing from one payment type to another does not retain stale selection/data;
- closing/reopening checkout does not leave tap/focus residue;
- Riwayat exposes only permitted actions;
- Menu does not reveal Owner-only administration.

Do not create an artificial financial fact solely for UAT. If a real sale is
appropriate during normal operation, record the observed result as stronger
evidence.

## Shift and packaging acceptance

Using an operationally valid shift:

- open/active state is immediately understandable;
- no stale numbers remain after moving between shifts;
- physical opening/closing fields start from the correct state;
- cup/packaging reconciliation uses the current shift and current physical input;
- no prior cash/QRIS/Kasbon choice visually persists into a new sale;
- browser Back does not strand an unresponsive overlay;
- closing flow remains blocked when required facts are missing.

Do not close or alter a live shift solely to satisfy UAT if that would disrupt
the gerai.

## Offline / resilience acceptance

With an authenticated preview session open:

1. switch the browser/device network offline;
2. confirm the global offline attention state appears;
3. confirm Offline & Sync reflects OFFLINE;
4. confirm the UI still states there is no offline mutation queue;
5. return online and confirm the state recovers.

No critical mutation needs to be submitted merely to prove the guard; the
executable online-action regression remains part of canonical verification.

## Evidence capture

For every defect record:

- role: Owner/Kasir;
- device/browser;
- route;
- exact action;
- expected result;
- observed result;
- screenshot/video if visual;
- severity P0/P1/P2/P3;
- whether reload changes the result.

For Product Media additionally record:

- source image type;
- approximate original size;
- whether upload/replace/remove completed;
- whether the photo appeared in Produk & Resep and Jual.

## Exit gate

F8 can be marked PASS only when:

- Owner real-device route matrix completed;
- Kasir real-device sale/navigation matrix completed;
- Product Media upload/replace/remove completed on the activated backend;
- no unresolved P0/P1 findings;
- responsive/touch issues found at real-device width are resolved or accepted;
- evidence is written back into this document;
- post-UAT F9 canonical regression is rerun.

Until then, status remains **READY FOR HUMAN UAT**.
