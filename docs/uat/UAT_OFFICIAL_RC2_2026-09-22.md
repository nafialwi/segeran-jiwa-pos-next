# Official UAT RC2 - 2026-09-22

Candidate tag: uat-rc-20260922-2
Candidate commit: d4776b64550550c17f484eb68132185bcdfb8896
Runtime source commit: 38aed0d0f59d8169cb9d5bdf3b583813371f56f0
Preview: https://3da4be58.segeran-jiwa-pos-next.pages.dev

## Entry gate

- C8 full cross-domain regression: 96/96 JavaScript + 289/289 Python PASS.
- C9 managed C2/C3 promotion: PASS.
- P5C backup health immediately before promotion: HEALTHY.
- Hosted schema / checkout coherence: PASS.
- GitHub canonical verify for RC2 tag commit: PASS.
- Cloudflare Pages Preview deployment: PASS.
- Chrome 153 mobile-width unauthenticated smoke: PASS.
- RC1 remains immutable.
- Production automatic deployment remains DISABLED.

Automated evidence supports UAT but does not replace human acceptance of authenticated workflows.

## C10 Human UAT batch A - Shell, navigation, responsive

Using an existing authorized Owner account on the exact RC2 Preview:

1. Sign in and confirm Home loads with readable identity and role.
2. Refresh once and confirm the authorized session restores without a blank screen.
3. Open Jual, Riwayat, Laporan, Stok, Pembelian, Produksi, Keuangan, Approval Pengeluaran, Shift Saya, Rekonsiliasi, and Control Center / settings surfaces available to Owner.
4. Confirm no final route falls back to a placeholder.
5. At phone width, verify Home, Jual, and one long-form screen have no blocking horizontal overflow or clipped primary controls.

Expected: shell/navigation/responsive PASS.

## C10 Human UAT batch B - Sales and payment

1. Confirm the catalog renders Product / Variant choices.
2. Confirm checkout exposes CASH, manual QRIS, TRANSFER, and CREDIT/Kasbon where authorized.
3. Confirm tracked zero-stock sale choices remain visibly blocked.
4. Confirm discount and line-note controls behave as designed where permitted.
5. For CASH, verify tendered amount/change presentation is clear before submit.

A real financial transaction is not required solely for visual acceptance. Do not create a production sale just to satisfy UAT unless the operator intentionally chooses a disposable transaction.

Expected: sales/payment PASS.

## C10 Human UAT batch C - Inventory, purchase, production

1. Open Stok and confirm location scope, stock state, and product/variant inventory presentation are readable.
2. Open Pembelian and confirm PO / receive / direct-buy controls are reachable where authorized.
3. Open Produksi and confirm production controls and recipe/BOM-derived surfaces are reachable.
4. Confirm supplier/payable and inventory screens do not show an Owner access error.
5. Confirm no duplicate inventory writer or conflicting stock action is exposed.

Expected: inventory/purchase/production PASS.

## C10 Human UAT batch D - Shift and finance

1. Open Shift Saya and Rekonsiliasi.
2. Confirm current shift, expected cash, live/actual cash, and variance are readable.
3. Confirm QRIS/TRANSFER/CREDIT are not presented as drawer cash.
4. Confirm close-shift remains gated by valid state.
5. Open Keuangan and Approval Pengeluaran and confirm Owner-only finance surfaces are readable.
6. Confirm customer debt, supplier payable, employee kasbon, and expense approval surfaces do not expose an access error.

Do not close the real operational shift or mutate real finance solely for UAT.

Expected: shift/finance PASS.

## C10 Human UAT batch E - History, reports, attention, backup, offline

1. Open Riwayat and inspect an existing transaction.
2. Confirm refund and correction are visually distinct and present preview/confirmation before mutation.
3. Open Laporan and confirm selector/date range, readable output, HPP coverage warning, and Excel export.
4. Disconnect network while signed in and confirm global offline / Perlu perhatian state appears.
5. Attempt a non-destructive critical write entry point and confirm final submit is blocked while offline.
6. Reconnect and confirm no queued or silently replayed mutation appears.
7. Open health/backup/diagnostic surfaces and confirm checkpoint evidence is readable and not falsely shown as green without evidence.

Expected: history/reports/attention/offline/health PASS.

## Exit rule

Official RC2 UAT may be marked PASS only when batches A-E have human acceptance evidence and no P0/P1 issue remains.

Any P0/P1 finding means: stop, patch source, rerun full regression, create the next immutable release candidate, rerun impacted smoke and UAT.

Current status: SUPERSEDED_BY_RC3.

## RC2 UAT finding

Authenticated Human UAT reached **Shift Saya** and exposed a P1 blocker:

`permission denied for table sales`

The failure came from the frontend packaging-usage helper directly reading the protected `public.sales` fact table. RC2 is therefore **SUPERSEDED_BY_RC3** and must not be accepted as the final UAT candidate.

Repair candidate: `uat-rc-20260922-3`.
