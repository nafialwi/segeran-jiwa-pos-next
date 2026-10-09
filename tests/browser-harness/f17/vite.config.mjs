import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const repo = path.resolve(here, '../../..');
const auth = path.join(here, 'stub-auth.ts');
const action = path.join(here, 'stub-action.ts');
const shift = path.join(here, 'stub-shift.ts');
const sales = path.join(here, 'stub-sales.ts');
const production = path.join(here, 'stub-production.ts');
const mocks = new Map([
  ['../auth/AuthProvider', auth],
  ['../components/ActionDialogProvider', action],
  ['../shift/shift-api', shift],
  ['../sales/sales-draft', sales],
  ['../production/production-api', production],
]);

export default defineConfig({
  root: repo,
  publicDir: path.join(repo, 'public'),
  plugins: [
    {
      name: 'f17-browser-fixture-only',
      enforce: 'pre',
      resolveId(source, importer) {
        if (!importer || !importer.startsWith(path.join(repo, 'src')))
          return null;
        return mocks.get(source) ?? null;
      },
    },
    react(),
  ],
  server: { host: '127.0.0.1', port: 4861, strictPort: true },
});
