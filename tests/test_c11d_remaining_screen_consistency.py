from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
OWNER = ROOT / "src/screens/OwnerUsersScreen.tsx"
REPORTS = ROOT / "src/screens/ReportsScreen.tsx"
HISTORY = ROOT / "src/screens/TransactionHistoryScreen.tsx"
MESSAGE = ROOT / "src/screens/OperationalMessageScreen.tsx"
CSS = ROOT / "src/app.css"


class C11DRemainingScreenConsistencyTests(unittest.TestCase):
    def test_remaining_secondary_screens_use_shared_state_component(self):
        for path in (OWNER, REPORTS, HISTORY, MESSAGE):
            source = path.read_text(encoding="utf-8")
            self.assertIn("OperationalState", source, path.name)

    def test_history_and_reports_have_explicit_loading_and_empty_copy(self):
        history = HISTORY.read_text(encoding="utf-8")
        reports = REPORTS.read_text(encoding="utf-8")
        self.assertIn('message="Memuat riwayat transaksi"', history)
        self.assertIn('title="Transaksi tidak ditemukan"', history)
        self.assertIn('message="Memuat laporan"', reports)
        self.assertIn('title="Laporan belum ditampilkan"', reports)

    def test_operational_message_feedback_is_accessible(self):
        source = MESSAGE.read_text(encoding="utf-8")
        self.assertIn('kind="error"', source)
        self.assertIn('role="status" aria-live="polite"', source)
        self.assertIn('message="Memuat pesan operasional"', source)
        self.assertIn('title="Belum ada pesan operasional"', source)

    def test_owner_empty_states_explain_next_condition(self):
        source = OWNER.read_text(encoding="utf-8")
        self.assertIn('title="Pengguna tidak ditemukan"', source)
        self.assertIn('title="Belum ada perangkat tercatat"', source)

    def test_long_text_overflow_is_hardened(self):
        css = CSS.read_text(encoding="utf-8")
        self.assertIn(
            "/* C11-D4 — remaining secondary-screen state & overflow convergence */",
            css,
        )
        self.assertIn(".operational-message-card p", css)
        self.assertIn("overflow-wrap: anywhere;", css)
        self.assertIn("white-space: pre-wrap;", css)


if __name__ == "__main__":
    unittest.main()
