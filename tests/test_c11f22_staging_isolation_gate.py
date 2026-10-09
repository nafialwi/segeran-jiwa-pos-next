from pathlib import Path
import json
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
GATE = ROOT / "scripts/staging-isolation-gate.mjs"
PRODUCTION = "a" * 20
STAGING = "b" * 20
OTHER = "c" * 20


class F22StagingIsolationGateTests(unittest.TestCase):
    def run_gate(self, url_ref=STAGING, preview_ref=STAGING,
                 production_ref=PRODUCTION, with_key=True, secret_key=False):
        with tempfile.TemporaryDirectory(prefix="sjpos-f22-readonly-") as dirname:
            staging_env = Path(dirname) / ".env.staging"
            key = "sb_secret_NOT_FOR_BROWSER" if secret_key else "sb_publishable_TEST_PUBLIC"
            staging_env.write_text(
                f"VITE_SUPABASE_URL=https://{url_ref}.supabase.co\n"
                + (f"VITE_SUPABASE_PUBLISHABLE_KEY={key}\n" if with_key else ""),
                encoding="utf-8",
            )
            before = staging_env.read_bytes()
            result = subprocess.run(
                ["node", str(GATE), "--staging-env", str(staging_env),
                 "--production-ref", production_ref, "--preview-ref", preview_ref],
                capture_output=True, text=True, timeout=12, check=False,
            )
            self.assertEqual(staging_env.read_bytes(), before)
            self.assertEqual(result.stderr, "")
            return result.returncode, json.loads(result.stdout)

    def test_isolation_config_pass_still_does_not_authorize_real_uat(self):
        code, info = self.run_gate()
        self.assertEqual(code, 0)
        self.assertEqual(info["status"], "CONFIG_DISTINCT_ONLY")
        self.assertFalse(info["uat_allowed"])
        self.assertEqual(info["staging_ref"], STAGING)
        self.assertEqual(info["preview_ref"], STAGING)

    def test_staging_equal_to_operational_is_blocked(self):
        code, info = self.run_gate(url_ref=PRODUCTION, preview_ref=PRODUCTION)
        self.assertEqual(code, 2)
        self.assertEqual(info["reason"], "STAGING_AND_OPERATIONAL_PROJECT_ARE_IDENTICAL")

    def test_preview_equal_to_operational_is_blocked(self):
        code, info = self.run_gate(preview_ref=PRODUCTION)
        self.assertEqual(code, 2)
        self.assertEqual(info["reason"], "PREVIEW_STILL_TARGETS_OPERATIONAL_PROJECT")

    def test_mismatched_preview_is_blocked(self):
        code, info = self.run_gate(preview_ref=OTHER)
        self.assertEqual(code, 2)
        self.assertEqual(info["reason"], "PREVIEW_AND_STAGING_PROJECT_DIFFER")

    def test_missing_publishable_key_blocks_without_leaking_secret(self):
        code, info = self.run_gate(with_key=False)
        self.assertEqual(code, 2)
        self.assertEqual(info["reason"], "STAGING_BROWSER_CONFIG_INCOMPLETE")

    def test_secret_key_is_never_accepted_for_browser(self):
        code, info = self.run_gate(secret_key=True)
        self.assertEqual(code, 2)
        self.assertEqual(info["reason"], "SERVER_CREDENTIAL_IN_BROWSER_CONFIG")
        self.assertNotIn("sb_secret_NOT_FOR_BROWSER", json.dumps(info))

    def test_current_environment_is_not_already_a_staging_env(self):
        self.assertFalse((ROOT / ".env.staging").exists())
        code = subprocess.run(
            ["node", str(GATE), "--staging-env", str(ROOT / ".env.staging"),
             "--production-ref", PRODUCTION, "--preview-ref", STAGING],
            capture_output=True, text=True, timeout=12, check=False,
        )
        self.assertEqual(code.returncode, 2)
        self.assertIn("STAGING_ENV_NOT_READABLE", code.stdout)

    def test_no_network_database_or_write_operations_in_gate(self):
        script = GATE.read_text(encoding="utf-8")
        for banned in ("fetch(", "http.request(", "https.request(", "writeFileSync(",
                       "createClient(", "execSync(", "spawn("):
            self.assertNotIn(banned, script)
        self.assertIn("readFileSync(", script)
        self.assertIn("uat_allowed: false", script)


if __name__ == "__main__":
    unittest.main()
