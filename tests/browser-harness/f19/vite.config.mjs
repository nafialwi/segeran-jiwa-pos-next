import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
const here = path.dirname(fileURLToPath(import.meta.url));
const repo = path.resolve(here, '../../..');
const f17 = path.resolve(here, '../f17');
const mocks = new Map([
  ['../auth/AuthProvider', path.join(f17, 'stub-auth.ts')],
  ['../components/ActionDialogProvider', path.join(f17, 'stub-action.ts')],
  ['../sales/sales-draft', path.join(f17, 'stub-sales.ts')],
  ['../shift/shift-api', path.join(here, 'stub-shift.ts')],
  ['../finance/finance-api', path.join(here, 'stub-finance.ts')],
  ['../inventory/inventory-control-api', path.join(here, 'stub-inventory.ts')],
]);
export default defineConfig({
  root: repo,
  publicDir: path.join(repo, 'public'),
  plugins: [
    {
      name: 'f19-browser-fixture-only',
      enforce: 'pre',
      resolveId(source, importer) {
        if (!importer || !importer.startsWith(path.join(repo, 'src')))
          return null;
        return mocks.get(source) ?? null;
      },
    },
    react(),
  ],
  server: { host: '127.0.0.1', port: 4863, strictPort: true },
});
