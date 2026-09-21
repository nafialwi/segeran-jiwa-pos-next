from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]


def exported_function_section(source: str, function_name: str) -> str:
    match = re.search(
        rf"export async function {re.escape(function_name)}\b",
        source,
    )
    if not match:
        raise AssertionError(f"Missing function {function_name}")
    tail = source[match.start():]
    next_match = re.search(r"\nexport async function \w+", tail[1:])
    if next_match:
        return tail[: next_match.start() + 1]
    return tail


class FinalP5BOfflineBoundariesTests(unittest.TestCase):
    def test_business_mutation_api_functions_are_online_guarded(self):
        expected = {
            "src/sales/sales-api.ts": ["checkoutSale"],
            "src/shift/shift-api.ts": [
                "openShift",
                "closeShift",
                "resolveHandover",
                "postShiftExpense",
            ],
            "src/finance/finance-api.ts": [
                "postFinanceTransfer",
                "postOwnerCapital",
                "postOwnerPersonalWithdrawal",
                "settleQris",
                "reconcileFinanceDay",
                "payCustomerDebt",
                "paySupplierPayable",
                "createEmployeeKasbon",
            ],
            "src/purchase/purchase-api.ts": [
                "createPurchaseSupplier",
                "createPurchaseItem",
                "createPurchaseOrder",
                "createGoodsReceipt",
                "directBuy",
                "postGoodsReceipt",
            ],
            "src/history/history-api.ts": [
                "refundSale",
                "previewSaleCorrection",
                "correctSale",
            ],
        }

        for relative, functions in expected.items():
            source = (ROOT / relative).read_text(encoding="utf-8")
            self.assertIn("requireOnlineAction", source, relative)
            for name in functions:
                self.assertIn(
                    "requireOnlineAction(",
                    exported_function_section(source, name),
                    f"{relative}:{name}",
                )

    def test_direct_admin_import_and_approval_mutations_are_guarded(self):
        expected = {
            "src/screens/ExpenseApprovalScreen.tsx": [
                "Perubahan rule approval",
                "Keputusan approval pengeluaran",
            ],
            "src/screens/OwnerUsersScreen.tsx": [
                "Administrasi pengguna",
                "Administrasi perangkat",
            ],
            "src/screens/LegacyImportScreen.tsx": ["Import master Legacy"],
        }

        for relative, labels in expected.items():
            source = (ROOT / relative).read_text(encoding="utf-8")
            for label in labels:
                self.assertIn("requireOnlineAction('" + label + "')", source)

    def test_boundary_does_not_create_an_offline_mutation_queue(self):
        source = (ROOT / "src" / "health" / "online-action.ts").read_text(
            encoding="utf-8"
        )
        self.assertIn("tidak diantrikan offline", source)
        for forbidden in ["localStorage", "indexedDB", "setInterval", "queue.push"]:
            self.assertNotIn(forbidden, source)


if __name__ == "__main__":
    unittest.main()
