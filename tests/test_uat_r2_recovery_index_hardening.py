from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[1]
M=ROOT/'supabase'/'migrations'/'20260920215500_uat_r2_recovery_index_hardening.sql'
class UatR2RecoveryIndexHardeningTests(unittest.TestCase):
    def test_covering_indexes_are_present(self):
        s=' '.join(M.read_text().lower().split())
        self.assertIn('business_checkout_settings_updated_by_idx',s)
        self.assertIn('legacy_master_imports_inventory_movement_idx',s)
if __name__=='__main__':
    unittest.main()
