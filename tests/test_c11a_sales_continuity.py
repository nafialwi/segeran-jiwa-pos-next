from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
SCREEN = ROOT / "src/screens/SalesScreen.tsx"
DRAFT = ROOT / "src/sales/sales-draft.ts"


class C11ASalesContinuityTests(unittest.TestCase):
    def test_cart_and_operation_identity_are_shift_scoped_and_persistent(self):
        source = SCREEN.read_text(encoding="utf-8")
        draft = DRAFT.read_text(encoding="utf-8")
        self.assertIn("loadSalesDraft", source)
        self.assertIn("saveSalesDraft", source)
        self.assertIn("clearSalesDraft", source)
        self.assertIn("pendingCheckout", source)
        self.assertNotIn("pendingOperationIdRef", source)
        self.assertIn("shiftId: shift.id", source)
        self.assertIn("operationId: crypto.randomUUID()", source)
        self.assertIn("checkoutSale(request)", source)
        self.assertIn("sj.sales.draft.v1", draft)

    def test_manual_payment_confirmation_is_not_persisted(self):
        draft = DRAFT.read_text(encoding="utf-8")
        self.assertNotIn("qrisConfirmed", draft)
        self.assertNotIn("transferConfirmed", draft)
        screen = SCREEN.read_text(encoding="utf-8")
        self.assertIn("setQrisConfirmed(false)", screen)
        self.assertIn("setTransferConfirmed(false)", screen)
        self.assertIn("Periksa transaksi sebelumnya", screen)
        self.assertIn("draft.pendingCheckout?.locationId === currentShift.location_id", screen)


if __name__ == "__main__":
    unittest.main()
