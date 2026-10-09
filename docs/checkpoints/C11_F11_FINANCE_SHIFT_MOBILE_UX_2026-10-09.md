# C11-F11 — Mobile Finance & Shift UX Safe Point

Date: 2026-10-09. Repository: `nafialwi/segeran-jiwa-pos-next`.
Branch: `work/c11e-preuat-readiness-termux`.
Baseline HEAD: `6a09cce1ba774a85740befa99011a510371ef35d`.
Design direction: four user-approved Segeran Jiwa POS Next reference images (visual targets, not application screenshots).

## Intent and Scope

Reduce vertical scrolling and forms shown simultaneously in Keuangan and Shift Saya, preserving current finance/shift data, permissions, transaction validations and all existing workflows.

## Keuangan

- Six KPI account/debt summary tiles stay visible and use unchanged values from the finance overview.
- Replace anchor jumps to stacked ten finance panels with a mobile-scrollable work selector, showing only selected work: Saldo, Pindah Uang, QRIS, Piutang, Utang Pemasok, Rekonsiliasi, Kasbon, Owner and Approval.
- All ten previous sections and forms stay in source and are still reachable through matching selector states. Form draft state remains in the parent component when switching panels.
- Payment, settlement, owner money movement, employee kasbon, customer receivables, supplier payables and expense approval retain their original handlers, permissions, confirmations, positive amount validation, and backend services.
- Customer-side debt terminology in UI is clarified as Piutang Pelanggan; business API semantics are unchanged.
- Correct opaque/technical copy such as settlement and money ledger descriptions.

## Shift Saya

- Active status, opening time, Lanjut Jual, opening cash, expected cash, cash sales, and cash out remain permanently visible for an active shift.
- Add one-row horizontally scrollable work navigation: Ringkasan, Kas Shift, Pengeluaran (only if authorized), Kemasan, Tutup Shift, Lainnya.
- Show one selected operational panel at a time. The existing stock packaging checks, cash variance preview, expense approval data, closure validations, open and close backend calls are unaltered.
- Reset selected work panel to Ringkasan on successfully opening or closing a shift.
- Non-active shifts still use the original Buka Shift Baru path.

## Verification boundary

- Six new C11-F11 structural regressions verify the workflow selectors, all business forms, permission guard for expense, shift transitions, closure and packaging safeguards, accessibility and mobile styling.
- One legacy menu-index assertion updated to match separated Piutang / Utang Pemasok; legacy finance front-door wording assertion updated to Piutang Pelanggan.
- Final lint / TypeScript / JS / Python / build results must be verified before release.
- No Supabase schema, RPC, payment implementation, inventory movement, deployment configuration or production data modified.
- Real authenticated Android QA at 320 / 360 / 390 / 412 px and Owner/Cashier acceptance remain outstanding. These screenshots are required for visual `V-PASS`.
- Final release / UAT / security / cutover gates remain pending; `CUTOVER_READY=NO` until all verified.
