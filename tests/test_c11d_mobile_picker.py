from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
PICKER = ROOT / "src/components/SearchablePicker.tsx"
CONTROL = ROOT / "src/screens/InventoryControlScreen.tsx"
CSS = ROOT / "src/app.css"


class C11DMobilePickerTests(unittest.TestCase):
    def test_inventory_control_long_item_lists_use_searchable_picker(self):
        src = CONTROL.read_text(encoding="utf-8")
        self.assertGreaterEqual(src.count("<SearchablePicker"), 3)
        self.assertIn("visibleCountItems", src)
        self.assertIn("Cari barang yang akan dihitung", src)
        self.assertNotIn("value={restockItemId}\n                  onChange", src)

    def test_picker_is_searchable_accessible_and_mobile_sheet(self):
        src = PICKER.read_text(encoding="utf-8")
        self.assertIn('role="dialog"', src)
        self.assertIn('aria-modal="true"', src)
        self.assertIn('role="listbox"', src)
        self.assertIn('type="search"', src)
        self.assertIn("setOpen(false)", src)

        css = CSS.read_text(encoding="utf-8")
        self.assertIn("/* C11-D mobile long-list correction */", css)
        self.assertIn(".searchable-item-dialog", css)
        self.assertIn("@media (max-width: 520px)", css)


if __name__ == "__main__":
    unittest.main()
