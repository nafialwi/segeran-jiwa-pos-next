from datetime import datetime, timedelta, timezone
from hashlib import sha256
import json
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "scripts/dev-uat-backup-gate.mjs"
PROJECT = "pkynjaqrxhhnnfuaxoqp"


def iso(date):
    return date.isoformat(timespec="seconds").replace("+00:00", "Z")


class DevUatBackupGateTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="sjpos-dev-uat-gate-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.bundle = self.root / "bundle"
        self.bundle.mkdir()
        self.archive = self.bundle / "dev.sql"
        self.archive.write_text("-- dummy fixture, not an actual backup\n")
        self.retained = self.root / "retained.sql"
        self.retained.write_bytes(self.archive.read_bytes())
        self.digest = sha256(self.archive.read_bytes()).hexdigest()
        self.created = datetime.now(timezone.utc).replace(microsecond=0) - timedelta(minutes=5)
        self.restore_time = self.created + timedelta(minutes=1)
        self.write_metadata()

    def write_metadata(self):
        (self.bundle / "backup-manifest.json").write_text(json.dumps({
            "format_version": 1, "project_ref": PROJECT,
            "created_at": iso(self.created),
            "logical_export": {"file": "dev.sql", "sha256": self.digest},
        }))
        (self.bundle / "restore-verification.json").write_text(json.dumps({
            "status": "PASS", "verified_at": iso(self.restore_time),
            "backup_sha256": self.digest,
            "method": "synthetic test fixture only",
        }))

    def check(self, minimum=None, project=PROJECT):
        if minimum is None:
            minimum = iso(self.created - timedelta(seconds=1))
        before = self.archive.read_bytes() if self.archive.exists() else None
        proc = subprocess.run([
            "node", str(SCRIPT),
            "--bundle-dir", str(self.bundle),
            "--retained-copy", str(self.retained),
            "--baseline-utc", minimum,
            "--project-ref", project,
        ], capture_output=True, text=True, check=False, timeout=12)
        self.assertEqual(before, self.archive.read_bytes() if self.archive.exists() else None)
        self.assertEqual(proc.stderr, "")
        return proc.returncode, json.loads(proc.stdout)

    def test_complete_synthetic_evidence_never_auto_approves_mutations(self):
        code, value = self.check()
        self.assertEqual(code, 0)
        self.assertEqual(value["status"], "BACKUP_EVIDENCE_PRESENT_REVIEW_REQUIRED")
        self.assertFalse(value["uat_mutations_allowed"])
        self.assertEqual(value["backup_sha256"], self.digest)

    def test_missing_backup_remains_blocked(self):
        self.archive.unlink()
        code, value = self.check()
        self.assertEqual(code, 2)
        self.assertEqual(value["reason"], "BACKUP_HEALTH_UNVERIFIED")

    def test_backup_older_than_baseline_is_blocked(self):
        code, value = self.check(minimum=iso(self.created + timedelta(minutes=1)))
        self.assertEqual(code, 2)
        self.assertEqual(value["reason"], "BACKUP_OLDER_THAN_BASELINE")

    def test_wrong_project_is_blocked(self):
        code, value = self.check(project="x" * 20)
        self.assertEqual(code, 2)
        self.assertEqual(value["reason"], "WRONG_PROJECT")

    def test_mismatched_retained_copy_is_blocked(self):
        self.retained.write_text("not the same backup")
        code, value = self.check()
        self.assertEqual(code, 2)
        self.assertEqual(value["reason"], "BACKUP_HEALTH_UNVERIFIED")

    def test_stale_restore_proof_is_blocked(self):
        self.restore_time = self.created - timedelta(seconds=5)
        self.write_metadata()
        code, value = self.check()
        self.assertEqual(code, 2)
        self.assertEqual(value["reason"], "RESTORE_EVIDENCE_PREDATES_BACKUP")

    def test_future_evidence_is_blocked(self):
        self.created = datetime.now(timezone.utc) + timedelta(hours=2)
        self.restore_time = self.created + timedelta(minutes=1)
        self.write_metadata()
        code, value = self.check()
        self.assertEqual(code, 2)
        self.assertEqual(value["reason"], "EVIDENCE_TIMESTAMP_IN_FUTURE")

    def test_no_data_mutation_or_database_network_calls(self):
        text = SCRIPT.read_text(encoding="utf-8")
        for unsafe in ("fetch(", "https.request(", "writeFileSync(",
                       "execSync(", "createClient(", "supabase.from("):
            self.assertNotIn(unsafe, text)
        self.assertIn("validateBackupBundle(", text)
        self.assertIn("uat_mutations_allowed: false", text)


if __name__ == "__main__":
    unittest.main()
