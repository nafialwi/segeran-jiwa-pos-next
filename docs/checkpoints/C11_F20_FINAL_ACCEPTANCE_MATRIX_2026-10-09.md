# C11-F20 — Visual acceptance matrix and path to final

This matrix distinguishes **actual React component rendered with fixture data**, **unsigned browser checks**, **static structural regression**, and **authenticated UAT**. "Fixture PASS" does not imply real Supabase data, workflow authority, or released UX acceptance.

| Area                           | Technical evidence in current branch   | Mobile screenshot / fixture                           | Real authenticated UAT on current HEAD | Next requirement                                                              |
| ------------------------------ | -------------------------------------- | ----------------------------------------------------- | -------------------------------------- | ----------------------------------------------------------------------------- |
| Login and branded entry        | F13 Chromium                           | Real unsigned login PASS (320–1280)                   | OPEN                                   | Login with Owner/Cashier, soft keyboard                                       |
| Jual / Keranjang / Checkout UI | F20 Chromium fixture                   | PASS (320, 360, 390, 412, 768, 1280)                  | OPEN                                   | Authenticated cash, QRIS, transfer, customer debt, receipt, duplicate submit  |
| Menu and Produksi              | F16–F17                                | Fixture PASS (320–1280)                               | OPEN                                   | Permissioned menus, live BOM, draft/post on staging                           |
| Laporan and Riwayat            | F10 / F18                              | Fixture PASS (320–1280)                               | OPEN                                   | Live data/filter/export/refund/correction readback                            |
| Keuangan and Shift Saya        | F11 / F19                              | Fixture PASS (320–1280)                               | OPEN                                   | Real reconciliation, shift/approval and cash movements                        |
| Pengguna & Izin                | F12 / F16                              | Source-level structural checks                        | OPEN                                   | Owner/staff account/device controls, negative role cases                      |
| Pembelian & Pemasok            | F12                                    | Source-level checks                                   | OPEN                                   | Supplier/PO/receiving/stock changes with real data                            |
| Persediaan                     | F12                                    | Source-level checks                                   | OPEN                                   | Counts, approvals, adjustment, transfer, authorization                        |
| Produk & Resep                 | F12                                    | Source-level checks                                   | OPEN                                   | Real product editing, variants, packaging, BOM, mobile navigation             |
| Performance / failed route     | F14 / F15                              | Chromium route splitting / recovery PASS in isolation | OPEN                                   | Real slow-network, chunk failure, return/reload, device test                  |
| Security / recoverability      | P5C/P5D historic Sep 22                | Old acceptance only                                   | REVIEW AGAIN                           | Revalidate current source/schema, credential/roles, backup/restore            |
| Production cutover             | Release manifest from older C10 commit | NOT READY                                             | NOT STARTED                            | Final UAT, new immutable candidate, explicit authorization, controlled deploy |

## Explicit readiness estimate (planning only)

This percentage is **not a measured operational production readiness score**. It is a transparent, deliberately conservative weighted estimate of the work toward **final** on current source, superseding the obsolete 99% from the C10 manifest. The degree of implementation and visual coverage is expert judgment, not a formal test acceptance metric.

| Dimension                             |   Weight |                          Estimated completion |     Contribution |
| ------------------------------------- | -------: | --------------------------------------------: | ---------------: |
| Existing feature/UX implementation    |      45% |                                95% (estimate) |         42.75 pp |
| Current automated quality gates       |      25% |                 100% (F20 local gates passed) |         25.00 pp |
| Isolated visual/browser acceptance    |      10% | 80% (not all modules visually fixture-tested) |          8.00 pp |
| Current-HEAD authenticated human UAT  |      15% |                                   0% accepted |          0.00 pp |
| Current-HEAD release/cutover approval |       5% |                                   0% accepted |          0.00 pp |
| **Overall estimate**                  | **100%** |                                               | **75.75% ≈ 76%** |

**Interpretation:** implementation and automated checks are advanced, but there is no new signed-off authenticated acceptance for commits after legacy C10 RC4. Old manifest has `whole_project_weighted_progress_percent=99` and older cutover status; it references `c86d4c0...`, not current HEAD. Its older UAT and security evidence remain historical facts, not proof of F20 production readiness.

A red/blocked **cutover gate overrides any numeric estimate**: release is **NOT authorized**. Next: signed-in Owner and Cashier browser walk-through, real staging tests, updated security/backup evidence, post-UAT regression, release manifest tied exactly to immutable final commit, and explicit approval before production deployment.
