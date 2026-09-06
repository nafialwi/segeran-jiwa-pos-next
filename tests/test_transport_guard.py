import unittest

from tools.mobile_inbox.transport_guard import select_single_zip


class TransportGuardTests(unittest.TestCase):
    def test_accepts_exactly_one_inbox_zip(self):
        self.assertEqual(
            select_single_zip([("A", "inbox/SJPOSNEXT-CS-01-R1.zip")]),
            "inbox/SJPOSNEXT-CS-01-R1.zip",
        )

    def test_rejects_two_zip_changes(self):
        with self.assertRaisesRegex(ValueError, "exactly one"):
            select_single_zip(
                [
                    ("A", "inbox/a.zip"),
                    ("A", "inbox/b.zip"),
                ]
            )

    def test_rejects_zip_plus_other_file(self):
        with self.assertRaisesRegex(ValueError, "exactly one"):
            select_single_zip(
                [
                    ("A", "inbox/a.zip"),
                    ("M", ".github/workflows/mobile-inbox-trigger.yml"),
                ]
            )

    def test_rejects_non_zip_change(self):
        with self.assertRaisesRegex(ValueError, "exactly one"):
            select_single_zip([("A", "inbox/readme.txt")])


if __name__ == "__main__":
    unittest.main()
