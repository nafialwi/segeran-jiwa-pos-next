export type LegacyMenuItem = Record<string, unknown>;
export type LegacyCustomer = Record<string, unknown>;

export type LegacyMasterPayload = {
  menu: LegacyMenuItem[];
  inventory: Record<string, unknown>;
  customers: LegacyCustomer[];
  settings: Record<string, unknown>;
};

function asRecord(value: unknown): Record<string, unknown> | null {
  if (!value || typeof value !== 'object' || Array.isArray(value)) return null;
  return value as Record<string, unknown>;
}

function normalizeCollection(value: unknown): Record<string, unknown>[] {
  if (Array.isArray(value)) {
    return value.filter(
      (item): item is Record<string, unknown> =>
        Boolean(item) && typeof item === 'object' && !Array.isArray(item),
    );
  }

  const record = asRecord(value);
  if (!record) return [];

  return Object.entries(record).flatMap(([key, value]) => {
    const row = asRecord(value);
    if (!row) return [];
    return [{ ...row, id: row.id ?? key }];
  });
}

function findGlobal(root: Record<string, unknown>): Record<string, unknown> {
  const direct = asRecord(root.global);
  if (direct && ('menu' in direct || 'inventory' in direct)) return direct;

  const legacyRoot = asRecord(root.toko_segeranjiwa_v58);
  const legacyGlobal = legacyRoot ? asRecord(legacyRoot.global) : null;
  if (legacyGlobal) return legacyGlobal;

  const data = asRecord(root.data);
  const dataGlobal = data ? asRecord(data.global) : null;
  if (dataGlobal) return dataGlobal;

  if ('menu' in root || 'inventory' in root) return root;

  throw new Error(
    'Backup tidak memuat node global/menu Legacy Segeran Jiwa yang dikenali.',
  );
}

export function parseLegacyMaster(value: unknown): LegacyMasterPayload {
  const root = asRecord(value);
  if (!root) throw new Error('File backup harus berupa object JSON.');

  const global = findGlobal(root);
  const menu = normalizeCollection(global.menu);
  const customers = normalizeCollection(global.customers);
  const inventory = { ...(asRecord(global.inventory) ?? {}) };
  const settings = asRecord(global.settings) ?? {};

  // Legacy stock authority first reads global.inventory[id], then falls back
  // to product.stok for older snapshots. Preserve that exact migration rule.
  for (const item of menu) {
    const id = String(item.id ?? '').trim();
    if (!id || inventory[id] !== undefined) continue;
    const legacyStock = Number(item.stok);
    if (Number.isFinite(legacyStock) && legacyStock >= 0) {
      inventory[id] = legacyStock;
    }
  }

  if (menu.length === 0) {
    throw new Error('Master produk Legacy kosong atau tidak ditemukan.');
  }

  return { menu, inventory, customers, settings };
}

export async function sha256Hex(buffer: ArrayBuffer): Promise<string> {
  const digest = await crypto.subtle.digest('SHA-256', buffer);
  return Array.from(new Uint8Array(digest))
    .map((value) => value.toString(16).padStart(2, '0'))
    .join('');
}

export function legacyMasterSummary(payload: LegacyMasterPayload) {
  const tracked = payload.menu.filter((item) => {
    const value = item.trackStock;
    return (
      value === true || value === 1 || String(value).toLowerCase() === 'true'
    );
  }).length;

  return {
    menuCount: payload.menu.length,
    trackedCount: tracked,
    customerCount: payload.customers.length,
    qrisPresent:
      typeof payload.settings.qris === 'string' &&
      payload.settings.qris.trim().length > 0,
  };
}
