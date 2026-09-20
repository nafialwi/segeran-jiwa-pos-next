# HRR-P3 Reports & Excel Foundation Design

Date: 2026-09-20
Blueprint baseline: v1.0 FINAL LOCK
Status: IMPLEMENTATION DESIGN

## Scope

HRR-P3 closes the minimum Reports + Excel capability required by the Blueprint:

- Laporan Penjualan
- Laporan Produk
- Laporan Persediaan
- Laporan Shift
- Laporan Pembelian
- Laporan Keuangan

Reports are read models over canonical facts and projections. They never create a second ledger.

## Permission model

- Owner: all reports.
- REPORT_SALES_LIMITED: Sales + Product.
- REPORT_INVENTORY: Inventory, respecting inventory location scope.
- REPORT_PURCHASE: Purchase.
- Shift report: Owner-only in the centralized Reports authority.
- Finance report: Owner-only.
- REPORT_PRODUCTION remains outside this minimum HRR-P3 scope.

## Period and reversal semantics

Sales facts are counted on their original business date. Refunds are separate reversal events counted on refund date. Net sales for a period are gross sales events minus refund events in that same period. Original completed sales are not rewritten.

Inventory includes a current stock snapshot plus period movement detail.

Finance uses canonical money facts, expenses and debt/payable projections.

## HPP / profit

Current authority data does not contain a complete canonical HPP source. HRR-P3 therefore reports HPP coverage as unavailable and does not present exact Net Profit. It must never assume HPP=0.

## Excel

Excel is a presentation artifact generated from the exact report envelope shown in UI. It must include business/report title, period, export timestamp, summary, structured tables, totals where applicable, Rupiah/number formatting, sticky header rows, reasonable widths, and multiple sheets where useful.

The browser exporter is loaded dynamically. Dependency audit must remain clear.
