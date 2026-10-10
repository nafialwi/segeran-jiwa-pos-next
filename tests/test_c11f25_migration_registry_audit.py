import importlib.util
import json
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / 'scripts/migration-registry-audit.py'
REGISTRY = ROOT / 'docs/checkpoints/C11_F25_SUPABASE_MIGRATION_REGISTRY_2026-10-10.json'
spec = importlib.util.spec_from_file_location('sjpos_migration_registry', SCRIPT)
audit_module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(audit_module)


class F25MigrationRegistryAudit(unittest.TestCase):
    def test_live_registry_snapshot_name_and_version_comparison(self):
        report = audit_module.audit(
            audit_module.local_history(ROOT / 'supabase/migrations'),
            audit_module.remote_history(REGISTRY))
        self.assertEqual(report['local_file_count'], 66)
        self.assertEqual(report['remote_registry_count'], 53)
        self.assertEqual(report['exact_version_and_name_count'], 11)
        self.assertEqual(report['name_matched_other_version_count'], 35)
        self.assertEqual(report['remote_without_local_name_count'], 7)
        self.assertEqual(report['local_without_remote_name_count'], 21)
        self.assertEqual(report['duplicate_remote_names'],
                         {'uat_r1_sale_replay_stock_gate': 2})
        self.assertEqual(report['status'], 'MANUAL_RECONCILIATION_REQUIRED')
        self.assertFalse(report['safe_to_automatically_push_migrations'])
        self.assertTrue(report['no_sql_equivalence_claim'])

    def test_both_unsafe_name_version_mismatch_scenarios_identified(self):
        local = [{'version':'20260101000000','name':'good_file'},
                 {'version':'20260101000001','name':'renamed_version'}]
        remote = [{'version':'20260101000000','name':'other_name'},
                  {'version':'20260102000001','name':'renamed_version'}]
        report = audit_module.audit(local, remote)
        self.assertEqual(len(report['same_version_different_name']), 1)
        self.assertEqual(report['name_matched_other_version_count'], 1)
        self.assertEqual(report['remote_without_local_name_count'], 1)

    def test_invalid_snapshot_project_is_denied(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / 'migrations.json'
            path.write_text(json.dumps({
                'project_ref':'x'*20,
                'migrations':[{'version':'20260101000000','name':'example'}]
            }))
            with self.assertRaisesRegex(ValueError, 'REMOTE_PROJECT_REF_INVALID'):
                audit_module.remote_history(path)

    def test_duplicate_versions_cannot_silently_overwrite(self):
        local = [{'version':'20260101000000','name':'x'},
                 {'version':'20260101000000','name':'y'}]
        remote = [{'version':'20260102000000','name':'x'}]
        with self.assertRaisesRegex(ValueError, 'DUPLICATE_VERSION_INVALID'):
            audit_module.audit(local, remote)

    def test_invalid_local_filename_fails_closed(self):
        with tempfile.TemporaryDirectory() as folder:
            (Path(folder) / 'migration.sql').write_text('SELECT 1;')
            with self.assertRaisesRegex(ValueError,'INVALID_LOCAL_MIGRATION_FILENAME'):
                audit_module.local_history(folder)

    def test_script_does_not_connect_to_database_or_write_sql(self):
        source = SCRIPT.read_text()
        for token in ('connect(', 'execute(', 'CREATE TABLE', 'ALTER TABLE',
                      'subprocess.run', 'psql', 'pg_dump', 'apply_migration',
                      'write_text(', 'write_bytes('):
            self.assertNotIn(token, source)
        self.assertIn('safe_to_reset_database', source)
        self.assertIn('False', source)

    def test_cli_reports_metadata_only(self):
        result = subprocess.run([
            'python3', str(SCRIPT),
            '--local-dir', str(ROOT / 'supabase/migrations'),
            '--remote-registry', str(REGISTRY)],
            capture_output=True, text=True, timeout=10)
        self.assertEqual(result.returncode,0, result.stderr)
        value = json.loads(result.stdout)
        self.assertEqual(value['status'],'MANUAL_RECONCILIATION_REQUIRED')
        self.assertFalse(value['safe_to_automatically_push_migrations'])


if __name__ == '__main__':
    unittest.main()
