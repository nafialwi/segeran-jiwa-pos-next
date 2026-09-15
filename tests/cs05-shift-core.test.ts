import { describe, expect, it } from 'vitest';
import {
  canAcceptHandover,
  canCloseShift,
  formatIdr,
  formatMovementLabel,
  formatVariance,
  reconciliationExpectedCash,
  reconciliationVariance,
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

describe('P4-B helpers', () => {
  it('formatIdr renders with prefix and decimals', () => {
    expect(formatIdr(1234.5)).toBe('Rp 1.234,50');
  });

  it('formatMovementLabel returns Indonesian labels', () => {
    expect(formatMovementLabel('CASH_IN')).toBe('Uang Masuk');
    expect(formatMovementLabel('CASH_OUT')).toBe('Uang Keluar');
    expect(formatMovementLabel('ADJUSTMENT')).toBe('Penyesuaian');
  });

  it('reconciliationExpectedCash sums correctly', () => {
    const r = {
      shift_id: 'x',
      opening_balance: 100000,
      sale_total: 50000,
      refund_total: 5000,
      cash_in_total: 10000,
      cash_out_total: 3000,
      adjustment_total: 2000,
      expected_cash: 0,
      actual_cash: null,
      variance: null,
    };
    expect(reconciliationExpectedCash(r)).toBe(154000);
  });

  it('reconciliationVariance computes actual minus expected', () => {
    const r = {
      shift_id: 'x',
      opening_balance: 100000,
      sale_total: 50000,
      refund_total: 0,
      cash_in_total: 0,
      cash_out_total: 0,
      adjustment_total: 0,
      expected_cash: 0,
      actual_cash: 148000,
      variance: 0,
    };
    expect(reconciliationVariance(r)).toBe(-2000);
  });

  it('reconciliationVariance returns null when actual is null', () => {
    const r = {
      shift_id: 'x',
      opening_balance: 0,
      sale_total: 0,
      refund_total: 0,
      cash_in_total: 0,
      cash_out_total: 0,
      adjustment_total: 0,
      expected_cash: 0,
      actual_cash: null,
      variance: null,
    };
    expect(reconciliationVariance(r)).toBeNull();
  });
});
