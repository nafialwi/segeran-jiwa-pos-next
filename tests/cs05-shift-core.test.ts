import { describe, expect, it } from 'vitest';
import {
  canAcceptHandover,
  canCloseShift,
  formatVariance,
  toShiftErrorMessage,
  type Handover,
  type Shift,
} from '../src/shift/shift-core';

function makeShift(status: 'OPEN' | 'CLOSED'): Shift {
  return {
    id: 'a',
    business_id: 'b',
    location_id: 'l',
    cashier_profile_id: 'c',
    opened_at: '2026-09-14T00:00:00Z',
    closed_at: status === 'CLOSED' ? '2026-09-14T08:00:00Z' : null,
    opening_balance: 100000,
    closing_balance: status === 'CLOSED' ? 150000 : null,
    status,
    config_snapshot: {},
    expected_cash: status === 'CLOSED' ? 150000 : null,
    actual_cash: status === 'CLOSED' ? 150000 : null,
    variance: status === 'CLOSED' ? 0 : null,
  };
}

function makeHandover(status: 'PENDING' | 'ACCEPTED'): Handover {
  return {
    id: 'h',
    business_id: 'b',
    location_id: 'l',
    from_shift_id: 'f',
    to_shift_id: null,
    from_cashier_profile_id: 'c1',
    to_cashier_profile_id: 'c2',
    expected_balance: 100000,
    actual_balance: 100000,
    discrepancy: 0,
    status,
    created_at: '2026-09-14T08:00:00Z',
  };
}

describe('shift-core rules', () => {
  it('canCloseShift true only for OPEN', () => {
    expect(canCloseShift(makeShift('OPEN'))).toBe(true);
    expect(canCloseShift(makeShift('CLOSED'))).toBe(false);
    expect(canCloseShift(null)).toBe(false);
  });

  it('canAcceptHandover true only for PENDING', () => {
    expect(canAcceptHandover(makeHandover('PENDING'))).toBe(true);
    expect(canAcceptHandover(makeHandover('ACCEPTED'))).toBe(false);
    expect(canAcceptHandover(null)).toBe(false);
  });

  it('formatVariance formats id-ID with sign', () => {
    expect(formatVariance(5000)).toBe('+5.000,00');
    expect(formatVariance(-3000)).toBe('-3.000,00');
    expect(formatVariance(0)).toBe('0,00');
    expect(formatVariance(null)).toBe('—');
  });

  it('maps CS05 business rule errors', () => {
    expect(
      toShiftErrorMessage(
        new Error('CS05: actor already has an open shift (AC-01)'),
      ),
    ).toContain('aturan bisnis dilanggar');
  });

  it('maps SJ permission and handover errors', () => {
    expect(toShiftErrorMessage(new Error('SJ_PERMISSION_DENIED'))).toContain(
      'tidak memiliki izin',
    );
    expect(toShiftErrorMessage(new Error('SJ_HANDOVER_NOT_PENDING'))).toContain(
      'sudah diproses',
    );
    expect(toShiftErrorMessage(new Error('SJ_SHIFT_NOT_OPEN'))).toContain(
      'Shift belum dibuka',
    );
  });

  it('passes through non-SJ errors', () => {
    expect(toShiftErrorMessage(new Error('Network timeout'))).toBe(
      'Network timeout',
    );
  });
});
