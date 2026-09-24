import { describe, expect, it } from 'vitest';
import {
  operationalStatusClass,
  statusLabel,
  statusToneClass,
} from '../src/ui/status-display';

describe('status display', () => {
  it('translates common operational statuses without changing backend values', () => {
    expect(statusLabel('DRAFT')).toBe('Draf');
    expect(statusLabel('POSTED')).toBe('Diposting');
    expect(statusLabel('PENDING')).toBe('Menunggu');
    expect(statusLabel('APPROVED')).toBe('Disetujui');
    expect(statusLabel('REJECTED')).toBe('Ditolak');
    expect(statusLabel('PARTIALLY_PAID')).toBe('Dibayar Sebagian');
  });

  it('uses predictable visual tones', () => {
    expect(statusToneClass('DRAFT')).toBe('neutral');
    expect(statusToneClass('PENDING')).toBe('warning');
    expect(statusToneClass('REJECTED')).toBe('danger');
    expect(statusToneClass('POSTED')).toBe('');
    expect(operationalStatusClass('REJECTED')).toBe(
      'operations-status danger',
    );
  });

  it('formats unknown enum values safely', () => {
    expect(statusLabel('WAITING_REVIEW')).toBe('Waiting Review');
  });
});
