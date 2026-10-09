from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
FIXTURE = ROOT / 'tests/browser-harness/f20'
CONFIG = (FIXTURE / 'vite.config.mjs').read_text()
MAIN = (FIXTURE / 'main.tsx').read_text()
CATALOG = (FIXTURE / 'stub-sales-api.ts').read_text()
DRAFT = (FIXTURE / 'stub-sales-draft.ts').read_text()
MEDIA = (FIXTURE / 'stub-product-media.ts').read_text()
RUNNER = (FIXTURE / 'verify-browser.py').read_text()


class C11F20SalesVisualFixture(unittest.TestCase):
    def test_dedicated_local_test_config_not_production(self):
        self.assertIn('f20-isolated-sales-ui-only', CONFIG)
        self.assertIn("host: '127.0.0.1'", CONFIG)
        self.assertNotIn('browser-harness', (ROOT / 'vite.config.ts').read_text())
        self.assertNotIn('browser-harness', (ROOT / 'src/main.tsx').read_text())

    def test_actual_sale_component_and_visible_fixture_warning(self):
        self.assertIn('src/screens/SalesScreen', MAIN)
        self.assertIn('src/components/AppShell', MAIN)
        self.assertIn('DATA CONTOH', MAIN)
        self.assertIn('PEMBAYARAN DINONAKTIFKAN', MAIN)

    def test_no_backend_checkout_or_persisted_draft(self):
        self.assertIn('async function checkoutSale', CATALOG)
        self.assertIn('throw new Error(', CATALOG)
        self.assertIn('Checkout dinonaktifkan', CATALOG)
        self.assertIn('function saveSalesDraft(): void {}', DRAFT)
        self.assertIn('function clearSalesDraft(): void {}', DRAFT)
        self.assertIn('function fetchProductMediaIndex', MEDIA)
        for value in (CATALOG, DRAFT, MEDIA):
            self.assertNotIn('supabase', value.lower())
            self.assertNotIn('fetch(', value)

    def test_six_viewports_and_sale_interactions(self):
        for dimensions in ('320,740', '360,800', '390,844', '412,915', '768,1024', '1280,800'):
            self.assertIn(dimensions, RUNNER)
        for token in ('sales-v2-product-card', 'sales-v2-cart-bar',
                      'sales-v2-cart-line', 'sales-v2-pay-button',
                      'sales-v2-variant-options', 'CASH_UI_READY',
                      'BROWSER_F20_PASS'):
            self.assertIn(token, RUNNER)
        self.assertIn('Never click the payment button', RUNNER)

    def test_fixture_has_real_browser_png_evidence(self):
        for file_name in ('jual-katalog-320.png', 'jual-keranjang-390.png',
                          'jual-varian-390.png', 'jual-katalog-1280.png'):
            self.assertTrue((ROOT / 'docs/visual-evidence/c11f20' / file_name).is_file())


if __name__ == '__main__':
    unittest.main()
