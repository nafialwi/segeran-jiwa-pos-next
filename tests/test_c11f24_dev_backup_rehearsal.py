from importlib.machinery import SourceFileLoader
import importlib.util
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest
from unittest.mock import patch
import urllib.error

ROOT = Path(__file__).resolve().parents[1]
SMOKE = ROOT / 'scripts/dev-uat-local-restore-smoke.sh'
EXPORT = ROOT / 'scripts/dev-uat-export-pg.sh'
AUTH = ROOT / 'scripts/dev-uat-edge-auth-negative.py'


class F24DevBackupRehearsalTests(unittest.TestCase):
    def test_local_rehearsal_is_isolated_and_cleans_up(self):
        code = SMOKE.read_text()
        for token in ("listen_addresses=''", 'unix_socket_directories', 'trap stop_and_remove EXIT',
                      'pg_dump -Fc', 'pg_restore --exit-on-error', 'FIXTURE_SUM_VERIFIED',
                      'unset PGPASSWORD', 'unset PGPASSWORD PGPASSFILE PGSERVICE PGSERVICEFILE PGHOSTADDR'):
            self.assertIn(token, code)
        self.assertNotIn('supabase.co', code)
        self.assertNotIn('password=', code.lower())

    def test_local_rehearsal_executes_if_postgres_is_installed(self):
        names = ('initdb', 'pg_ctl', 'postgres', 'pg_dump', 'pg_restore', 'psql', 'createdb')
        if not all(shutil.which(x) for x in names):
            self.skipTest('Isolated local PostgreSQL utilities not installed on CI')
        proc = subprocess.run(['bash', str(SMOKE)], capture_output=True, text=True,
                              timeout=45, check=False)
        if 'cannot be run as root' in proc.stdout + proc.stderr:
            self.skipTest('Local PostgreSQL initdb does not run as root')
        self.assertEqual(proc.returncode, 0, proc.stdout[-1200:] + proc.stderr[-1200:])
        self.assertIn('ISOLATED_RESTORE_SMOKE=PASS', proc.stdout)
        self.assertIn('HOSTED_SUPABASE_CONTACTED=NO', proc.stdout)

    def test_export_requires_explicit_execution_and_rejects_wrong_host(self):
        no_exec = subprocess.run(['bash', str(EXPORT)], capture_output=True,
                                 text=True, timeout=5, check=False)
        self.assertEqual(no_exec.returncode, 2)
        self.assertIn('BACKUP_EXPORT=BLOCKED', no_exec.stdout)
        bad_host = subprocess.run(
            ['bash', str(EXPORT), '--host', 'example.org', '--port', '5432',
             '--user', 'postgres', '--execute'],
            capture_output=True, text=True, timeout=5, check=False,
        )
        self.assertEqual(bad_host.returncode, 2)
        self.assertIn('endpoint not recognized', bad_host.stdout)

    def test_export_never_automatically_grants_uat_or_stores_password(self):
        code = EXPORT.read_text()
        self.assertIn('PGSSLMODE=require', code)
        self.assertIn('--password', code)
        self.assertIn('umask 077', code)
        self.assertIn('UAT_MUTATIONS_ALLOWED=NO', code)
        self.assertIn('RESTORE_PROOF=NOT_VERIFIED', code)
        self.assertIn('RETAINED_COPY=NOT_VERIFIED', code)
        self.assertNotIn('restore-verification.json', code)
        self.assertNotIn('PGPASSWORD=', code)

    def test_live_edge_probe_is_explicit_and_nonmutating(self):
        text = AUTH.read_text()
        self.assertIn('__f24_auth_denial_probe__', text)
        self.assertIn("if not args.live:", text)
        self.assertIn("status == 401 and code == 'SJ_AUTH_REQUIRED'", text)
        self.assertNotIn('service_role', text.split('def post_negative')[1])
        no_live = subprocess.run(['python3', str(AUTH)], capture_output=True,
                                 text=True, timeout=5, check=False)
        self.assertEqual(no_live.returncode, 2)
        self.assertIn('BLOCKED', no_live.stdout)

    def test_edge_config_validation_rejects_wrong_project_and_server_key(self):
        loader = SourceFileLoader('sj_f24_edge', str(AUTH))
        spec = importlib.util.spec_from_loader(loader.name, loader)
        module = importlib.util.module_from_spec(spec)
        loader.exec_module(module)
        with tempfile.TemporaryDirectory() as path:
            env = Path(path) / '.env'
            env.write_text('VITE_SUPABASE_URL=https://wrong.supabase.co\n'
                           'VITE_SUPABASE_PUBLISHABLE_KEY=sb_publishable_test\n')
            with self.assertRaises(ValueError):
                module.read_dev_config(env)
            env.write_text('VITE_SUPABASE_URL=https://pkynjaqrxhhnnfuaxoqp.supabase.co\n'
                           'VITE_SUPABASE_PUBLISHABLE_KEY=sb_secret_FORBIDDEN\n')
            with self.assertRaises(ValueError):
                module.read_dev_config(env)
            env.write_text('VITE_SUPABASE_URL=https://pkynjaqrxhhnnfuaxoqp.supabase.co\n'
                           'VITE_SUPABASE_PUBLISHABLE_KEY=sb_publishable_TEST\n')
            uri, key = module.read_dev_config(env)
            self.assertIn('pkynjaqrxhhnnfuaxoqp', uri)
            self.assertEqual(key, 'sb_publishable_TEST')

    def test_edge_mock_enforces_only_explicit_unauthorized_results(self):
        loader = SourceFileLoader('sj_f24_edge_mock', str(AUTH))
        spec = importlib.util.spec_from_loader(loader.name, loader)
        module = importlib.util.module_from_spec(spec)
        loader.exec_module(module)
        fake = urllib.error.HTTPError('https://local.test', 401, 'Unauthorized', {}, None)
        fake.read = lambda n: b'{"error":{"code":"SJ_AUTH_REQUIRED"}}'
        with patch.object(module.urllib.request, 'urlopen', side_effect=fake):
            code, result = module.post_negative(
                'https://pkynjaqrxhhnnfuaxoqp.supabase.co',
                'sb_publishable_FAKE', 'identity-admin',
            )
        self.assertEqual((code, result), (401, 'SJ_AUTH_REQUIRED'))


if __name__ == '__main__':
    unittest.main()
