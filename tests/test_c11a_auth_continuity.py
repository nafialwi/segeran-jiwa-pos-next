from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
PROVIDER = ROOT / "src/auth/AuthProvider.tsx"
APP = ROOT / "src/App.tsx"
LOGIN = ROOT / "src/screens/LoginScreen.tsx"


class C11AAuthContinuityTests(unittest.TestCase):
    def test_transient_bootstrap_failure_preserves_local_session(self):
        source = PROVIDER.read_text(encoding="utf-8")
        self.assertIn("kind: 'verification_failed'", source)
        self.assertIn("isTerminalAuthorityError", source)
        self.assertIn("clearLocalSession: false", source)
        self.assertIn("clearLocalSession: true", source)

    def test_retry_path_exists_without_forcing_login_form(self):
        provider = PROVIDER.read_text(encoding="utf-8")
        app = APP.read_text(encoding="utf-8")
        login = LOGIN.read_text(encoding="utf-8")
        self.assertIn("retryVerification", provider)
        self.assertIn("Sesi tetap tersimpan", app)
        self.assertIn("Memulihkan sesi", login)
        self.assertIn("Tidak perlu masuk ulang", login)


if __name__ == "__main__":
    unittest.main()
