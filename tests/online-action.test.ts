import { describe, expect, it } from 'vitest';
import { requireOnlineAction } from '../src/health/online-action';

describe('P5B online-only action boundary', () => {
  it('allows an online action', () => {
    expect(() => requireOnlineAction('Penjualan', true)).not.toThrow();
  });

  it('fails closed while offline with an explicit no-queue message', () => {
    expect(() => requireOnlineAction('Penjualan', false)).toThrow(
      'Penjualan memerlukan koneksi internet aktif dan tidak diantrikan offline.',
    );
  });
});
