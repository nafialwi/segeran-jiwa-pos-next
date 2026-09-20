# HRR-P3 CHECKPOINT REPORT

Project: segeran-jiwa-pos-next
Checkpoint: HRR-P3 Reports & Excel Foundation
Date: 2026-09-21
Branch: work/cs06743-patch3-hardening
Status: LOCKED_REMOTE after final safepoint push

## Blueprint authority

HRR-P3 completes the Blueprint minimum report surface:

- Laporan Penjualan
- Laporan Produk
- Laporan Persediaan
- Laporan Shift
- Laporan Pembelian
- Laporan Keuangan

Reports are read models over canonical facts/projections. They do not create a second ledger.

Excel output is presentation-ready: business/report title, period, export timestamp, summary, structured tables, totals where applicable, Rupiah/number formatting, sticky header rows, sensible widths, and multiple sheets.

## Source safepoint

- Technical implementation: f76cde572ed2fe60857e52ca28967e0bdc1d3c78
- Excel executable test follow-up: 9b02545efb37378cefe7e99c8ca6f56ed4dbf237
- Managed migration: hrr_p3_reports_excel

## Permission contract

- Owner: all six reports.
- REPORT_SALES_LIMITED: Sales + Product.
- REPORT_INVENTORY: Inventory with canonical location scope.
- REPORT_PURCHASE: Purchase.
- Shift centralized report: Owner-only.
- Finance report: Owner-only.

A non-owner cannot obtain Shift or Finance report data by navigating directly to the RPC.

## Report semantics

- Sales are counted on original business date.
- Refunds are separate reversal events counted on refund date.
- Period net sales = period gross sales - period refund events.
- Original completed sales are not rewritten.
- Inventory exposes current scoped balance plus movement detail.
- Purchase reports canonical PO / receipt / payable projections.
- Finance reads canonical account balances, money movements, expenses, customer debt, supplier payable and employee kasbon projections.

## HPP / profit safety

Canonical HPP authority is not yet complete for all active products.

HRR-P3 therefore:

- explicitly reports HPP coverage as unavailable;
- emits a visible warning;
- leaves exact Estimasi Laba null;
- never assumes HPP = 0.

This prevents a false net-profit claim.

## Excel implementation

Dependency: write-excel-file 4.1.1.

- dynamically imported in the browser;
- npm audit: 0 vulnerabilities;
- summary sheet plus one sheet per report section;
- sticky header rows;
- explicit column widths;
- numeric / Rupiah formatting;
- deterministic .xlsx filename.

Executable exporter test verifies the multi-sheet workbook contract rather than relying only on static source checks.

## Verification

Final canonical verification:

- JS: 74/74 PASS
- Python: 187/187 PASS
- format: PASS
- lint: PASS
- typecheck: PASS
- build: PASS
- git diff --check: PASS
- npm audit: 0 vulnerabilities

## Hosted verification

Managed migration applied successfully:

- hrr_p3_reports_excel

Owner runtime smoke executed all six report branches successfully.

Transaction-scoped hosted rollback regression returned:

HRR_P3_HOSTED_REGRESSION_PASS

Verified and rolled back:

- sale event increases Sales gross/count;
- refund event increases refund total without changing period net after sale+full refund;
- Product report tracks sold/refunded/net quantity coherently;
- Finance report exposes HPP coverage warning and no fabricated profit value;
- explicit REPORT_SALES_LIMITED can access Sales/Product;
- explicit REPORT_PURCHASE can access Purchase;
- explicit REPORT_INVENTORY can access Inventory;
- Inventory rows obey GERAI-only location scope;
- non-owner Shift is denied;
- non-owner Finance is denied;
- temporary fixture sale/refund/user/receipts do not persist.

Post-regression cleanliness:

- temporary users: 0
- temporary sales: 0
- temporary refunds: 0
- temporary operation receipts: 0
- real Owner shift remains OPEN
- real expected cash remains Rp17.000

## Advisor disposition

Supabase advisor reports authenticated access to SECURITY DEFINER report_run. This is intentional. The function pins search_path='', resolves current authority server-side, is STABLE/read-only, and enforces per-report permissions or Owner-only boundaries. Hosted negative tests verify the boundary.

No report fact table or second ledger was introduced.

## Bucket acceptance

HRR-P1 Transaction History: LOCKED_REMOTE.
HRR-P2 Sale Refund / Reversal Authority: LOCKED_REMOTE.
HRR-P3 Reports & Excel Foundation: LOCKED_REMOTE.

The complete History, Reversal/Refund, Reports & Excel bucket acceptance gate is CLEAR.

Roadmap weight earned: 7.0%.

Whole-project weighted progress moves from 88.0% to 95.0%.

## Next action

Attention, Offline, Backup, Health & Cutover Hardening.

Final 5.0% remains unearned until cutover-hardening acceptance is locked.
