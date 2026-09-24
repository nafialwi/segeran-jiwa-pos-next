from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
REPORTS = ROOT / "src/screens/ReportsScreen.tsx"
CSS = ROOT / "src/app.css"
REPORT_API = ROOT / "src/reports/report-api.ts"


class C11F42ReportInformationArchitectureTests(unittest.TestCase):
    def test_semantic_row_identity_is_section_aware(self):
        source = REPORTS.read_text(encoding="utf-8")
        self.assertIn("function semanticCompactRow(", source)
        for identity in [
            "SALES:transactions",
            "INVENTORY:balances",
            "INVENTORY:movements",
            "SHIFT:shifts",
            "PURCHASE:orders",
            "PURCHASE:receipts",
            "FINANCE:accounts",
            "FINANCE:money",
            "FINANCE:expenses",
            "FINANCE:customer_debts",
            "FINANCE:supplier_payables",
            "FINANCE:kasbon",
        ]:
            self.assertIn(identity, source)

    def test_finance_money_uses_source_reference_and_time_not_income_as_identity(self):
        source = REPORTS.read_text(encoding="utf-8")
        block = source[source.index("if (identity === 'FINANCE:money')"):]
        block = block[: block.index("if (identity === 'FINANCE:expenses')")]
        self.assertIn("const source = compactEnum(rawKey(row, 'sumber'))", block)
        self.assertIn("rawKey(row, 'referensi')", block)
        self.assertIn("formattedKey(section, row, 'created_at')", block)
        self.assertIn("firstNonEmpty(source, reason, kind, 'Arus Uang')", block)

    def test_debt_rows_use_party_identity_and_balance(self):
        source = REPORTS.read_text(encoding="utf-8")
        self.assertIn("rawKey(row, 'pelanggan')", source)
        self.assertIn("rawKey(row, 'pemasok')", source)
        self.assertIn("rawKey(row, 'karyawan')", source)
        self.assertIn("moneyKey(section, row, 'balance', 'original_amount')", source)
        self.assertIn("return 'Piutang Pelanggan';", source)

    def test_normal_status_is_quiet_but_attention_status_can_surface(self):
        source = REPORTS.read_text(encoding="utf-8")
        self.assertIn("if (!options.always && normal.has(upper)) return {};", source)
        self.assertIn("statusTone: normal.has(upper)", source)
        self.assertIn("normal: ['COMPLETED']", source)
        self.assertIn("report-compact-status", source)

    def test_mobile_density_count_and_empty_state_are_compact(self):
        css = CSS.read_text(encoding="utf-8")
        marker = "/* C11-F4.2 — report information architecture & semantic density */"
        self.assertIn(marker, css)
        final = css[css.index(marker):]
        self.assertIn("min-height: 52px;", final)
        self.assertIn("width: max-content;", final)
        self.assertIn(".report-section-empty", final)
        self.assertIn("padding: 10px 12px;", final)
        self.assertIn(".report-section-heading", final)
        self.assertIn("flex-direction: row;", final)

    def test_report_authority_and_export_truth_remain_unchanged(self):
        source = REPORTS.read_text(encoding="utf-8")
        api = REPORT_API.read_text(encoding="utf-8")
        self.assertIn("await runReport(code, dateFrom, dateTo)", source)
        self.assertIn("await exportReportExcel(report)", source)
        self.assertIn("supabase.rpc('report_run'", api)
        self.assertNotIn("supabase.from(", source)


if __name__ == "__main__":
    unittest.main()
