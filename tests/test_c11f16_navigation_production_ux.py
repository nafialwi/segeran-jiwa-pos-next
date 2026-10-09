from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
MENU = (ROOT / "src/screens/MenuScreen.tsx").read_text(encoding="utf-8")
OWNER = (ROOT / "src/screens/OwnerUsersScreen.tsx").read_text(encoding="utf-8")
CONTROL = (ROOT / "src/screens/ControlCenterScreen.tsx").read_text(encoding="utf-8")
PRODUCTION = (ROOT / "src/screens/ProductionScreen.tsx").read_text(encoding="utf-8")
CSS = (ROOT / "src/app.css").read_text(encoding="utf-8")


class NavigationProductionUxTests(unittest.TestCase):
    def test_menu_discovers_only_entries_authorized_by_existing_checks(self):
        self.assertRegex(MENU, r"useState<\s*'operations' \| 'business' \| 'system'\s*>\('operations'\)")
        self.assertIn("setMenuSearch(event.target.value)", MENU)
        self.assertIn("aria-label=\"Kategori menu\"", MENU)
        self.assertIn("menuCategory === 'operations'", MENU)
        self.assertIn("menuCategory === 'business'", MENU)
        self.assertIn("menuCategory === 'system'", MENU)
        self.assertIn("visibleEntries(operations)", MENU)
        self.assertIn("visibleEntries(business)", MENU)
        self.assertIn("visibleEntries(system)", MENU)
        self.assertIn("hasPermission(authority", MENU)
        self.assertIn("hasAnyPermission(authority", MENU)
        self.assertIn("canAccessOwnerArea(authority)", MENU)
        self.assertIn("hasSalesDraftForProfile", MENU)
        self.assertIn("fetchMyOpenShift", MENU)
        self.assertIn("confirmAction", MENU)

    def test_owner_navigation_links_select_correct_context(self):
        self.assertIn("'/pengguna#permissions'", CONTROL)
        self.assertIn("'/pengguna#devices'", CONTROL)
        self.assertIn("useLocation()", OWNER)
        self.assertIn("location.hash === '#devices'", OWNER)
        self.assertIn("location.hash === '#permissions'", OWNER)
        self.assertIn("Pilih pengguna untuk melihat perangkat", OWNER)
        self.assertIn("Pilih staf untuk melihat dan mengatur izinnya.", OWNER)
        self.assertIn("userDetailTab === 'devices'", OWNER)
        self.assertIn("userDetailTab === 'permissions'", OWNER)
        self.assertIn("owner_list_users", OWNER)
        self.assertIn("setPermission(", OWNER)
        self.assertIn("revokeAndRemoveDevice", OWNER)

    def test_production_is_split_without_altering_api_writes(self):
        self.assertRegex(PRODUCTION, r"useState<\s*'plan' \| 'batches' \| 'recipes'\s*>\('plan'\)")
        self.assertIn("aria-label=\"Pilih pekerjaan produksi\"", PRODUCTION)
        for flow in ("plan", "batches", "recipes"):
            self.assertIn(f"productionFlow === '{flow}'", PRODUCTION)
        self.assertIn("batchFilter === 'ALL' || batch.status === batchFilter", PRODUCTION)
        self.assertIn("aria-label=\"Status batch\"", PRODUCTION)
        self.assertIn("visibleBatches.map((batch)", PRODUCTION)
        self.assertIn("Math.ceil(batchList.length / 10)", PRODUCTION)
        self.assertIn("Halaman batch", PRODUCTION)
        self.assertIn("await createProductionBatch({", PRODUCTION)
        self.assertIn("await postProductionBatch({ batchId, actualOutput })", PRODUCTION)
        self.assertIn("result.already_posted", PRODUCTION)
        self.assertIn("setBatchFilter('POSTED')", PRODUCTION)
        self.assertIn("maksimal 50", PRODUCTION)

    def test_responsive_menu_and_production_controls(self):
        self.assertIn("/* C11-F16 — findable menu", CSS)
        self.assertIn(".menu-category-tabs", CSS)
        self.assertIn(".production-flow-tabs", CSS)
        self.assertIn(".production-batch-filters", CSS)
        self.assertIn(".production-batch-pagination", CSS)
        self.assertIn("min-height: var(--sj-touch-min);", CSS)


if __name__ == "__main__":
    unittest.main()
