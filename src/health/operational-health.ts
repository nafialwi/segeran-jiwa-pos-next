export type OperationalHealth = {
  connectivity: 'ONLINE' | 'OFFLINE';
  needsAttention: boolean;
  title: string;
  detail: string;
};

export function deriveOperationalHealth(isOnline: boolean): OperationalHealth {
  if (!isOnline) {
    return {
      connectivity: 'OFFLINE',
      needsAttention: true,
      title: 'Perlu perhatian: perangkat offline',
      detail:
        'Koneksi internet tidak terdeteksi. Operasi yang memerlukan layanan server dapat gagal sampai perangkat kembali online.',
    };
  }

  return {
    connectivity: 'ONLINE',
    needsAttention: false,
    title: 'Koneksi perangkat tersedia',
    detail:
      'Status konektivitas perangkat saja; bukan pernyataan bahwa layanan backend atau database sehat.',
  };
}
