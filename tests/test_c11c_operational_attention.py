from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
HOME = ROOT / "src/screens/HomeScreen.tsx"
ATTENTION = ROOT / "src/screens/AttentionScreen.tsx"


class C11COperationalAttentionTests(unittest.TestCase):
    def test_attention_does_not_claim_clear_while_unread_instruction_exists(self):
        home = HOME.read_text(encoding="utf-8")
        attention = ATTENTION.read_text(encoding="utf-8")
        self.assertIn("messageNeedsAttention", home)
        self.assertIn("operationalNeedsAttention", attention)
        self.assertIn("!operationalNeedsAttention", attention)
        self.assertIn("operationalCheckReady", attention)

    def test_high_priority_unread_instruction_has_visible_priority(self):
        home = HOME.read_text(encoding="utf-8")
        attention = ATTENTION.read_text(encoding="utf-8")
        self.assertIn("message.priority === 'HIGH'", home)
        self.assertIn("highUnreadCount + ' pesan penting belum dibaca'", home)
        self.assertIn("operationalHighUnread", attention)
        self.assertIn("pesan penting belum dibaca", attention)


if __name__ == "__main__":
    unittest.main()
