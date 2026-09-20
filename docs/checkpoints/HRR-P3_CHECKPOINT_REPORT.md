# HRR-P3 CHECKPOINT REPORT

Project: segeran-jiwa-pos-next
Checkpoint: HRR-P3 Reports & Excel Foundation
Date: 2026-09-21
Branch: work/cs06743-patch3-hardening
Status: LOCKED_REMOTE after final safepoint push

## Blueprint authority

HRR-P3 implements the minimum Owner reports required by Blueprint v1.0 FINAL LOCK:

- Laporan Penjualan
- Laporan Produk
- Laporan Persediaan
- Laporan Shift
- Laporan Pembelian
- Laporan Keuangan

Reports are projections/read-models over canonical facts. They do not create a second ledger or mutate business facts.

Kasir does not receive business Finance reporting. Other operational report access remains permission-based.

Excel export is presentation-ready rather than a raw dump and carries title, period, export timestamp, summary, structured tables, totals where relevant, number/Rupiah formatting, sticky/frozen headers, practical column widths and multiple worksheets.

HPP is not silently treated as zero. Where canonical HPP authority is unavailable, the report exposes the coverage gap and does not publish exact Net Profit.

## Source safepoint

- Reports implementation: f76cde5
- Excel workbook contract test: 9b02545efb37378cefe7e99c8ca6f56ed4dbf237
- Managed migration: hrr_p3_reports_excel

## Implemented contract

HRR-P3 adds:

- single /laporan report front door;
- public.report_run(report_code, date_from, date_to) read-only report authority;
- six Blueprint minimum reports;
- Owner access to all six reports;
- REPORT_SALES_LIMITED access to Sales + Product;
- REPORT_INVENTORY access to Inventory with inventory location scope enforced;
- REPORT_PURCHASE access to Purchase;
- Shift and Finance centralized reports remain Owner-only;
- Sales report with transaction, product and payment-method projections;
- full-sale refund events remain separate reversal events in period reporting;
- Product performance report;
- Inventory current balance snapshot plus period movement detail;
- Shift report based on canonical shift/cash facts;
- Purchase report based on purchase orders, goods receipts and supplier-payable projection;
- Finance report based on canonical money movements, business expenses, customer debt, supplier payable and employee kasbon projections;
- explicit HPP coverage warning and null exact-profit value while canonical HPP is incomplete;
- .xlsx export using write-excel-file/browser loaded dynamically;
- multi-sheet workbook generated from the exact report envelope shown in UI.

## Dependency verification

- npm audit --omit=dev: 0 vulnerabilities
- Excel dependency: write-excel-file 4.1.1
- exporter is dynamically loaded into a separate browser chunk.

## Verification

Final canonical verification:

- JS: 74/74 PASS
- Python: 187/187 PASS
- format: PASS
- lint: PASS
- typecheck: PASS
- build: PASS
- git diff --check: PASS
- local HEAD = remote HEAD before checkpoint lock

## Hosted verification

Managed migration is present:

- hrr_p3_reports_excel

Hosted transactional regression returned:

HRR_P3_HOSTED_REGRESSION_PASS

Verified:

- Owner can execute SALES, PRODUCT, INVENTORY, SHIFT, PURCHASE and FINANCE;
- every report returns the canonical report envelope with summary and sections;
- Finance emits an HPP coverage warning;
- Estimasi Laba remains null rather than assuming HPP = 0;
- REPORT_SALES_LIMITED unlocks Sales + Product only;
- REPORT_INVENTORY respects explicit location scope and does not leak Gudang when only Gerai is granted;
- Purchase is denied without REPORT_PURCHASE;
- REPORT_PURCHASE unlocks Purchase only;
- Shift and Finance remain Owner-only for the centralized report authority.

The temporary Kasir fixture was fully rolled back:

- temporary profile/user: 0
- temporary auth user: 0
- temporary permission override: 0
- temporary inventory scope: 0

## Advisor disposition

No new HRR-P3 table or RLS surface was created.

report_run is intentionally an authenticated SECURITY DEFINER read RPC. It pins search_path='', resolves the current authority server-side, enforces report permissions and inventory location scope, and creates no ledger/fact writes. Permission-negative hosted behavior was explicitly tested.

Existing RLS-no-policy informational findings and existing SECURITY DEFINER warnings belong to the established command/read boundary pattern. Existing unused-index notices are not introduced by HRR-P3.

## Verdict

CLEAR. HRR-P3 Reports & Excel Foundation is locked.

The History, Reversal/Refund, Reports & Excel 7% roadmap bucket is not yet credited. Blueprint distinguishes Refund/Pengembalian from Koreksi/Pembalikan, so the remaining correction/reversal acceptance must be audited before the complete bucket can be declared closed.

Whole-project earned progress remains 88.0%.

## Next action

HRR-P4 Correction/Reversal Closure Audit.

Audit the implemented HRR-P1/HRR-P2/HRR-P3 surface against Blueprint section 14. If a distinct completed-transaction correction/replacement authority is still missing, implement it without mutating the original fact; otherwise document evidence that the acceptance contract is already satisfied. Only after that audit may the 7% HRR bucket be considered for closure.
