import importlib.util
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch
import urllib.error

ROOT = Path(__file__).resolve().parents[1]
PATH = ROOT / 'scripts/dev-uat-xp-anon-negative.py'
spec = importlib.util.spec_from_file_location('sjpos_f25_xp_negative', PATH)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class F25XpSecurityRegressions(unittest.TestCase):
    def test_four_allowlisted_functions_use_unregistered_identity(self):
        self.assertEqual(len(module.BODIES), 4)
        self.assertEqual(
            set(module.BODIES),
            {'xp_agent_heartbeat_v2', 'xp_claim_job_v2',
             'xp_finish_job_v2', 'xp_renew_job_v2'})
        for arguments in module.BODIES.values():
            self.assertEqual(arguments['p_agent_id'], module.FAKE_AGENT)
        self.assertNotIn('x-agent-token', PATH.read_text().split('def check_rpc')[1].split('def main')[0])

    def test_live_probe_must_be_explicit(self):
        proc = subprocess.run(['python3', str(PATH)], capture_output=True,
                              text=True, timeout=5)
        self.assertEqual(proc.returncode, 2)
        self.assertIn('BLOCKED', proc.stdout)

    def test_wrong_project_and_secret_key_denied(self):
        with tempfile.TemporaryDirectory() as tmp:
            file = Path(tmp) / '.env'
            file.write_text("VITE_SUPABASE_URL=https://bad.supabase.co\n"
                            "VITE_SUPABASE_PUBLISHABLE_KEY=sb_publishable_test\n")
            with self.assertRaises(ValueError):
                module.read_public_dev_settings(file)
            file.write_text("VITE_SUPABASE_URL=https://pkynjaqrxhhnnfuaxoqp.supabase.co\n"
                            "VITE_SUPABASE_PUBLISHABLE_KEY=sb_secret_bad\n")
            with self.assertRaises(ValueError):
                module.read_public_dev_settings(file)

    def test_mocked_missing_agent_token_returns_postgrest_403(self):
        err = urllib.error.HTTPError('https://example.test', 403, 'Forbidden',
                                     {}, None)
        err.read = lambda n: b'{"code":"28000","message":"agent authentication failed"}'
        with patch.object(module.urllib.request, 'urlopen', side_effect=err):
            status, code = module.check_rpc(
                'https://pkynjaqrxhhnnfuaxoqp.supabase.co',
                'sb_publishable_mock', 'xp_claim_job_v2',
                {'p_agent_id': module.FAKE_AGENT})
        self.assertEqual((status, code), (403, '28000'))

    def test_no_real_agent_credentials_or_db_mutation_code(self):
        source = PATH.read_text()
        for token in ('PGPASSWORD', 'service_role_key', 'createClient(',
                      'pg_dump', 'DELETE FROM', 'UPDATE ', 'INSERT INTO',
                      'execute_sql(', 'x-agent-token\':'):
            self.assertNotIn(token, source)


if __name__ == '__main__':
    unittest.main()
