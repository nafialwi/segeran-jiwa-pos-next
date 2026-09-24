import { describe, expect, it } from 'vitest';
import {
  clearSalesDraft,
  loadSalesDraft,
  saveSalesDraft,
} from '../src/sales/sales-draft';

function memoryStorage() {
  const values = new Map<string, string>();
  return {
    getItem(key: string) {
      return values.get(key) ?? null;
    },
    setItem(key: string, value: string) {
      values.set(key, value);
    },
    removeItem(key: string) {
      values.delete(key);
    },
  };
}

describe('C11-A sales draft continuity', () => {
  it('round-trips a shift-scoped draft and pending checkout operation', () => {
    const storage = memoryStorage();
    saveSalesDraft(storage, {
      profileId: 'profile-1',
      shiftId: 'shift-1',
      lines: [{ variantId: 'v-1', quantity: 2, lineNote: 'less ice' }],
      method: 'CASH',
      cashReceived: 20000,
      customerId: '',
      note: 'counter',
      discountType: 'NONE',
      discountValue: 0,
      discountReason: '',
      pendingCheckout: {
        operationId: 'op-1',
        locationId: 'loc-1',
        items: [{ variant_id: 'v-1', quantity: 2 }],
        method: 'CASH',
        total: 12000,
        tenderedAmount: 20000,
        discount: { type: 'NONE', value: 0 },
        note: 'counter',
      },
    });

    const restored = loadSalesDraft(storage, 'profile-1', 'shift-1');
    expect(restored?.lines[0]).toEqual({
      variantId: 'v-1',
      quantity: 2,
      lineNote: 'less ice',
    });
    expect(restored?.pendingCheckout?.operationId).toBe('op-1');
  });

  it('does not restore a draft into a different shift or profile', () => {
    const storage = memoryStorage();
    saveSalesDraft(storage, {
      profileId: 'profile-1',
      shiftId: 'shift-1',
      lines: [],
      method: 'CASH',
      cashReceived: 0,
      customerId: '',
      note: '',
      discountType: 'NONE',
      discountValue: 0,
      discountReason: '',
      pendingCheckout: null,
    });

    expect(loadSalesDraft(storage, 'profile-1', 'shift-2')).toBeNull();
    expect(loadSalesDraft(storage, 'profile-2', 'shift-1')).toBeNull();
  });

  it('fails closed on malformed local draft data and supports explicit clear', () => {
    const storage = memoryStorage();
    storage.setItem(
      'sj.sales.draft.v1:profile-1:shift-1',
      JSON.stringify({ version: 1, profileId: 'profile-1' }),
    );
    expect(loadSalesDraft(storage, 'profile-1', 'shift-1')).toBeNull();

    saveSalesDraft(storage, {
      profileId: 'profile-1',
      shiftId: 'shift-1',
      lines: [],
      method: 'CASH',
      cashReceived: 0,
      customerId: '',
      note: '',
      discountType: 'NONE',
      discountValue: 0,
      discountReason: '',
      pendingCheckout: null,
    });
    clearSalesDraft(storage, 'profile-1', 'shift-1');
    expect(loadSalesDraft(storage, 'profile-1', 'shift-1')).toBeNull();
  });
  it('treats unavailable storage as best-effort instead of throwing', () => {
    const brokenStorage = {
      getItem() {
        throw new Error('blocked');
      },
      setItem() {
        throw new Error('quota');
      },
      removeItem() {
        throw new Error('blocked');
      },
    };

    expect(() =>
      saveSalesDraft(brokenStorage, {
        profileId: 'profile-1',
        shiftId: 'shift-1',
        lines: [],
        method: 'CASH',
        cashReceived: 0,
        customerId: '',
        note: '',
        discountType: 'NONE',
        discountValue: 0,
        discountReason: '',
        pendingCheckout: null,
      }),
    ).not.toThrow();
    expect(loadSalesDraft(brokenStorage, 'profile-1', 'shift-1')).toBeNull();
    expect(() =>
      clearSalesDraft(brokenStorage, 'profile-1', 'shift-1'),
    ).not.toThrow();
  });

});
