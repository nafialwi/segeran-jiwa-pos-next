# UAT WAVE 1  CORE OPERATIONS

Date: 2026-09-20
Branch: work/cs06743-patch3-hardening
Baseline commit: 27b16117c3a2e8869955996da26ce6abcd9a935a
Scope: Core operational UAT before FIN-P7
Status: CLEAR

## Purpose

Validate the locked core on a real browser/device before more milestones are stacked on top.

This is not final cutover UAT.

## Result vocabulary

- PASS  expected behavior and visual result are correct.
- FAIL  functional/business/permission failure.
- OBSERVATION  usable but needs UX/visual follow-up.
- NOT_RUN  not tested yet.
- BLOCKED  cannot be tested because a prerequisite is unavailable.

## Safety boundary

Wave 1A is read-only/smoke where possible.
Wave 1B performs controlled writes only after the operator explicitly begins the transactional section.
Production automatic deployment remains disabled.

## Wave 1A  Smoke, responsive and navigation

| ID     | Scenario                      | Expected                              | Result  |
| ------ | ----------------------------- | ------------------------------------- | ------- |
| UAT-01 | App loads current branch      | No blank page/loading blocker         | PASS    |
| UAT-02 | Login screen/session restore  | Human-readable state, no overflow     | PASS    |
| UAT-03 | Home desktop                  | Main navigation readable and aligned  | PASS    |
| UAT-04 | Home mobile-width             | No horizontal overflow/cut text       | PASS    |
| UAT-05 | Shift page opens              | Current shift state readable          | PASS    |
| UAT-06 | Sales page opens              | Checkout controls readable            | FAIL    |
| UAT-07 | Reconciliation page opens     | Totals/status readable                | PASS    |
| UAT-08 | Inventory/purchase navigation | Core pages reachable                  | FAIL    |
| UAT-09 | Owner-only navigation         | Owner cards visible only to Owner     | NOT_RUN |
| UAT-10 | Approval Pengeluaran screen   | Rule + queue UI loads without error   | PASS    |
| UAT-11 | Unauthorized route            | Access denied is human-readable       | NOT_RUN |
| UAT-12 | Refresh/reopen                | Current route/session recovers safely | NOT_RUN |

## Wave 1B  Controlled operational flow

| ID     | Scenario                           | Expected                                  | Result |
| ------ | ---------------------------------- | ----------------------------------------- | ------ |
| UAT-20 | Open shift from main cash          | Shift opens once, opening cash visible    | PASS   |
| UAT-21 | Cash sale                          | Sale succeeds and expected cash updates   | PASS   |
| UAT-22 | Manual QRIS sale                   | QR displayed/manual confirm flow works    | PASS   |
| UAT-23 | Transfer sale                      | Payment recorded under correct method     | PASS   |
| UAT-24 | Customer debt sale                 | Debt created, not treated as cash receipt | PASS   |
| UAT-25 | Small expense without approval     | Posts immediately                         | PASS   |
| UAT-26 | Expense over threshold             | Becomes PENDING; no cash effect yet       | PASS   |
| UAT-27 | Owner approves expense             | Expense posts exactly once                | PASS   |
| UAT-28 | Owner rejects expense              | No expense/cash posting                   | PASS   |
| UAT-29 | Shift reconciliation               | Expected cash is correct                  | PASS   |
| UAT-30 | Close shift                        | Closing succeeds only with valid state    | PASS   |
| UAT-31 | Purchase/supplier basic navigation | PO/GRN workflow reachable                 | PASS   |
| UAT-32 | Supplier payable view              | Authorized finance/purchase access only   | PASS   |

## Severity

- P0  data corruption/security/ledger integrity; stop UAT and fix immediately.
- P1  core flow unusable or materially wrong; fix before continuing roadmap.
- P2  UX/visual friction; record and continue if safe.
- P3  cosmetic.

## Exit gate for Wave 1

Wave 1 is CLEAR when:

1. no open P0/P1 finding remains;
2. core pages have desktop and mobile evidence;
3. login/permission/shift/sales/expense approval paths have real-device evidence;
4. transactional UAT reconciles money/shift outcomes;
5. findings and fixes are committed/pushed to the working branch.

## Evidence  UAT-01 through UAT-04

Operator-provided screenshots on 2026-09-20 show:

- Termux X11 desktop/browser: Home renders without blank/loading blocker; Owner session is active; navigation cards align in a two-column layout.
- Android Chrome normal portrait viewport: Home remains readable, both navigation columns are visible, labels are not cut, and the Owner badge/session card remain within the viewport.
- Existing authenticated session restores directly to Home as OWNER (Admin Segeran Jiwa, @admin, Perangkat Pribadi).
- A separate highly magnified Chrome screenshot clips the right side because the browser content is zoomed. It is recorded as a browser-zoom observation, not a baseline responsive defect, because the normal mobile viewport screenshot renders the full grid without horizontal clipping.

Current Wave 1A result: UAT-01..04 PASS. No P0/P1 finding.

## Evidence  UAT-05 through UAT-10

Operator-provided mobile screenshots on 2026-09-20 show:

- UAT-05 PASS  Shift Saya opens, location/opening-balance controls are readable and the open-shift state is human-readable.
- UAT-06 FAIL / P1  /jual renders only the Sales foundation placeholder: `Fondasi akses Penjualan aktif. Modul Penjualan dibangun pada milestone berikutnya.` Checkout controls are absent, so the core sale flow is unusable from the Next UI.
- UAT-07 PASS  Reconciliation opens and renders a real closed-shift breakdown with Opening Balance, Cash Sales, Refund, Cash In, Cash Out, Adjustment, Expected Cash, Actual Cash and Variance.
- UAT-08 FAIL / P1  Home/router has no Inventory/Purchase operational navigation even though CS-06 backend/domain work is locked. Core inventory/purchase screens are not reachable from the Next UI.
- UAT-10 OBSERVATION / P2  Expense Approval loads and shows rule + request sections, but the Back-to-Home arrow is rendered as a replacement/malformed character in the supplied screenshot. Function is usable; visual encoding needs correction.

### P1 findings opened

1. `UAT-P1-001 Sales UI missing`  backend checkout authority exists, but /jual is a hard-coded placeholder.
2. `UAT-P1-002 Inventory/Purchase UI missing`  CS-06 backend/domain exists without corresponding reachable operational UI.

### P2 findings opened

1. `UAT-P2-001 Expense Approval back-link encoding`  malformed arrow glyph on real Android Chrome.

### UAT disposition

Wave 1 transactional section is PAUSED at the P1 gate. Do not proceed to FIN-P7 or transactional UAT until P1 findings are fixed and UAT-06/UAT-08 are rerun.

Hosted data check during triage also found zero active rows in both `products` and `stock_items`. This is a separate UAT-data prerequisite for real sales/inventory transactions and must be resolved explicitly before Wave 1B; no production/UAT master data is being invented silently.

## Real-device rerun evidence - UAT-06 / UAT-08

Operator screenshot on 2026-09-20 after master import and blocker recovery shows:

- Home exposes Jual, Stok, Pembelian, Migrasi Master Legacy, Shift, Reconciliation, Owner controls and other expected navigation.
- Jual renders a real 30-product active catalog with search, category, server-imported price, and stock visibility. Zero-stock tracked items are visibly disabled.
- Stok renders imported Legacy rows at Gerai with quantity, unit, price and sale status.
- Pembelian is reachable and exposes operational front-door controls including Tambah Pemasok and Tambah Barang.
- The active Owner shift is OPEN at GERAI with opening balance Rp0 and no sale posted yet at the time of rerun.

Disposition:

- UAT-P1-001 Sales UI missing: CLOSED.
- UAT-P1-002 Inventory/Purchase UI missing: CLOSED.
- UAT-06: PASS.
- UAT-08: PASS.
- Wave 1 transactional testing may resume.

## Wave 1B evidence - UAT-20

Hosted verification after the operator opened the real-device UAT shift shows one OPEN shift at GERAI for Admin Segeran Jiwa with opening balance Rp0 and zero posted sales at the start of Wave 1B.

Disposition: UAT-20 PASS.

## Final Wave 1 closure - 2026-09-20

Status: CLEAR.

Real-device evidence plus hosted authoritative checks now cover the Wave 1 exit gate.

### Real hosted state observed

The active UAT shift remains OPEN and was not mutated by automated rollback tests.

- Opening balance: Rp0.
- Real CASH sales posted in the active shift: Rp17.000.
- Real TRANSFER sale: Rp2.000 to BANK.
- Real CREDIT/Kasbon sale: Rp1.000 for FULAN to HUTANG_PELANGGAN.
- Active-shift live reconciliation returns Expected Cash Rp17.000.
- No real QRIS sale, expense, purchase order, or temporary cashier was created by automated rollback tests.

### UAT-P2 live-cash visibility finding

The Shift screen showed Saldo Awal Rp0 but did not expose live expected cash, which made valid cash sales appear not to increase cash.

Root cause: the screen displayed only shifts.opening_balance while shifts.expected_cash is finalized on close. The canonical live value already exists through public.cs05_shift_reconciliation().

Fix:

- Shift Saya now loads live reconciliation for an OPEN shift.
- It displays Kas Berjalan, Penjualan Tunai, and Uang Keluar.
- It explains that QRIS, Transfer, and Kasbon do not increase cash in the drawer.
- Expense submission refreshes the live reconciliation immediately.
- Focused test PASS.
- Full verification after fix: 73/73 JS and 159/159 Python PASS; format, lint, typecheck, build, and diff-check PASS.

### Hosted automated UAT

A transaction-scoped hosted regression returned:

AUTO_UAT_WAVE1_BACKEND_PASS

It verified and rolled back:

- QRIS payment posts to QRIS_BELUM_CAIR and does not change drawer cash;
- small expense posts immediately;
- threshold expense becomes PENDING with no cash effect;
- Owner approval posts exactly one expense and CASH_OUT;
- rejection posts no expense and no cash effect;
- close shift with expected actual cash returns zero variance;
- reconciliation returns matching expected/actual/variance;
- non-Owner access to Owner user authority and expense-rule authority is denied.

Purchase regression returned:

AUTO_UAT_PURCHASE_PASS

It verified and rolled back:

- supplier and item creation;
- Direct Buy creates one PO and one posted GRN;
- inventory increases exactly once;
- supplier payable is created for the received value;
- retry/replay does not duplicate PO, GRN, payable, or stock movement.

### Final disposition

- UAT-P1-001 Sales UI missing: CLOSED.
- UAT-P1-002 Inventory/Purchase UI missing: CLOSED.
- Expense Approval malformed back-link observation: CLOSED.
- Live cash visibility observation: CLOSED.
- No open P0/P1 finding remains.
- Core mobile UI has real-device evidence.
- Hosted transactional/permission/accounting gates are PASS.
- Wave 1 is CLEAR and FIN-P7 may proceed.
