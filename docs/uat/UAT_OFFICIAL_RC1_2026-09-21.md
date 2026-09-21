# Official UAT RC1 - 2026-09-21

Candidate tag: uat-rc-20260921-1
Candidate commit: e844f9b9ad07ca240e1ba4f72a39c6c7aefbb489
Preview: https://5188a6b0.segeran-jiwa-pos-next.pages.dev

## Entry gate

- P5A Operational Health: LOCKED_REMOTE.
- P5B Offline Action Boundaries: LOCKED_REMOTE.
- P5C Backup Health: HEALTHY.
- P5C isolated restore verification: PASS.
- P5D security review: CLEAR_OR_ACCEPTED.
- Pre-UAT regression: 91/91 JavaScript + 205/205 Python PASS.
- Candidate tag immutable and source-equivalent to the current documentation HEAD.
- Cloudflare Preview deployment: PASS.
- Production automatic deployment: DISABLED.

## Automated evidence already accepted

- Canonical repository verification: PASS.
- GitHub canonical-verify check: PASS.
- Cloudflare Pages preview deployment: PASS.
- Isolated SQL UAT suite: 4/4 PASS.
- Existing transactional rollback authority tests remain PASS.
- No runtime/source delta exists between RC1 and the documentation-only HEAD.

These checks are supporting evidence only. They do not replace human acceptance of user-visible workflows.

## Automated browser smoke on the deployed RC1 source

A Linux Chrome 153 headless smoke was executed against the Cloudflare preview at a 390x844 mobile viewport.

- HTTP load: PASS.
- Login UI rendered: PASS.
- Global offline attention banner after browser network-offline emulation: PASS.
- Page errors: 0.
- Console errors: 0.

This reduces the remaining human gate to authenticated, user-visible acceptance.

## Human acceptance gate

Use an existing authorized Owner account. Do not create synthetic production users or alter credentials solely for UAT.

### UAT-H01 - Login and session

Open the exact RC1 preview, sign in with the normal Owner account, confirm Home loads with readable identity/role, then refresh once and confirm the authorized session recovers without a blank screen.

### UAT-H02 - Main navigation and final surfaces

From Home, open Jual, Riwayat, Laporan, Stok, Pembelian, Keuangan, Approval Pengeluaran, Shift Saya, and Rekonsiliasi.

Expected: every screen is reachable and readable and no final feature route falls back to a placeholder.

### UAT-H03 - Operational health and offline boundary

While signed in, disconnect the network. Confirm the global Perlu perhatian: perangkat offline state appears. Attempt one non-destructive critical write entry point and confirm final submit is blocked with an active-internet/no-offline-queue message. Reconnect.

Expected: no queued or silently replayed mutation and no duplicate action after reconnect.

### UAT-H04 - Sales and payment visibility

Verify the catalog renders and checkout exposes CASH, manual QRIS, TRANSFER where authorized, and CREDIT/Kasbon where authorized. Tracked zero-stock items must remain visibly blocked.

A real financial transaction is not required solely for this UI acceptance if operational data should not be mutated.

### UAT-H05 - History, refund, and correction

Open Riwayat and inspect an existing transaction. Confirm filters/search are usable, refund and correction are visually distinct, correction presents preview/confirmation, and corrected/refunded state is human-readable.

Do not execute refund/correction against a real business transaction solely for UAT unless the operator explicitly chooses a disposable transaction.

### UAT-H06 - Reports and Excel

Open Laporan. Confirm report selector/date range work, report output is readable, HPP coverage warning is visible when exact profit cannot be proven, and Excel export is available.

### UAT-H07 - Finance, purchase, and inventory

Open Keuangan, Pembelian, and Stok. Confirm Finance Owner front door is readable, purchase/GRN/direct-buy controls are reachable where authorized, inventory/location scope is readable, and supplier/payable surfaces do not expose an access error to the Owner.

### UAT-H08 - Shift and reconciliation

Open Shift Saya and Rekonsiliasi. Confirm current shift state and live/expected cash are readable, non-cash payment methods are not presented as drawer cash, and close-shift controls remain gated by valid state.

Do not close the real operational shift solely for UAT unless the operator intends to close it.

### UAT-H09 - Mobile-width smoke

Repeat Home, Jual, and one long-form screen at phone width or on the real phone. Confirm no horizontal overflow hides primary controls, no clipped text prevents use, and modals/sheets remain usable.

## Exit rule

Official UAT may be marked PASS only when UAT-H01 through UAT-H09 have human acceptance evidence and no P0/P1 issue remains.

P0/P1 finding means stop, patch source, full regression, create RC2, and rerun impacted UAT plus smoke regression.

Current status: AWAITING_HUMAN_ACCEPTANCE.
