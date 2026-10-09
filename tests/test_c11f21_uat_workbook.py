from pathlib import Path
import json
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]
WORKBOOK = ROOT / 'docs/uat/UAT_C11_F21_OPERATOR_WORKBOOK_2026-10-09.html'
HTML = WORKBOOK.read_text(encoding='utf-8')
DATA = re.search(r'<script id="uat-cases" type="application/json">(.*?)</script>', HTML, re.S)
CASES = json.loads(DATA.group(1)) if DATA else []
RUNNER = (ROOT / 'tests/browser-harness/f21/verify-browser.py').read_text()


class UatF21WorkbookTests(unittest.TestCase):
    def test_single_file_offline_and_complete_role_workflows(self):
        self.assertIn('<!doctype html>', HTML.lower())
        self.assertEqual(44, len(CASES))
        self.assertEqual(len(CASES), len({c['id'] for c in CASES}))
        groups = {c['group'] for c in CASES}
        self.assertEqual(groups, {'Akun', 'Kasir', 'Owner', 'Keamanan', 'Perangkat', 'Rilis'})
        for case in CASES:
            self.assertEqual(set(case), {'id','group','priority','role','title','steps'})
            self.assertIn(case['priority'], ('P0','P1','P2'))
            self.assertIn(case['role'], ('Owner','Kasir'))
            self.assertGreater(len(case['steps']), 24)

    def test_critical_idempotency_and_guard_paths_are_explicit(self):
        all_cases = ' '.join(c['steps'] + ' ' + c['title'] for c in CASES).lower()
        for word in ('operation id', 'invoice', 'stok', 'shift', 'qris', 'transfer',
                     'kasbon', 'pemasok', 'restore', 'keyboard', 'perangkat', 'offline'):
            self.assertIn(word, all_cases)
        for id_ in ('K07','K12','K15','O03','O05','O08','S01','S02','G04'):
            matched = next(x for x in CASES if x['id'] == id_)
            self.assertEqual(matched['priority'], 'P0')

    def test_never_auto_approves_release_or_injects_network_dependency(self):
        self.assertIn('CUTOVER_READY=NO', HTML)
        self.assertRegex(HTML, r'releaseApproved:\s*false')
        self.assertIn('p0fail', HTML)
        self.assertIn("const allowed = [", HTML)
        for status in ('PENDING', 'PASS', 'FAIL', 'BLOCKED'):
            self.assertIn(repr(status), HTML)
        self.assertRegex(HTML, r"status: \'PENDING\', note: \'\'")
        self.assertNotIn('<script src=', HTML)
        self.assertNotIn('<link rel="stylesheet" href=', HTML)
        self.assertNotIn('fetch(', HTML)
        self.assertNotIn('XMLHttpRequest(', HTML)

    def test_storage_export_import_validates_candidate_and_does_not_send_data(self):
        self.assertIn('SJPOSNEXT_F21_UAT_V1', HTML)
        self.assertIn("data.candidate !== '0fafee4'", HTML)
        self.assertIn('file.size > 2_000_000', HTML)
        self.assertIn('localStorage', HTML)
        self.assertIn('URL.createObjectURL', HTML)
        self.assertIn('Jangan memasukkan password', HTML)

    def test_browser_runner_keeps_evidence_pending_and_no_live_credentials(self):
        for value in ('320,740', '390,844', '768,1024'):
            self.assertIn(value, RUNNER)
        self.assertIn('BROWSER_F21_PASS', RUNNER)
        self.assertIn("item['passed']=='0'", RUNNER)
        self.assertIn("p0=js", RUNNER)
        for size in (320, 390, 768):
            self.assertTrue((ROOT / f'docs/visual-evidence/c11f21/uat-workbook-pending-{size}.png').is_file())


if __name__ == '__main__':
    unittest.main()
