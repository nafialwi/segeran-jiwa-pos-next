from pathlib import Path
import unittest

ROOT=Path(__file__).resolve().parents[1]
M=ROOT/"supabase"/"migrations"/"20260920214500_uat_r1_sale_replay_stock_gate.sql"

class UatR1SaleReplayStockGateTests(unittest.TestCase):
    def test_replay_gate_precedes_stock_low_gate(self):
        self.assertTrue(M.exists())
        s=" ".join(M.read_text().lower().split())
        self.assertIn("'inventory_tracked', v_inventory_tracked",s)
        self.assertLess(s.index("if v_lock.replay then"), s.index("sj_stock_low"))

if __name__=="__main__":
    unittest.main()
