import { describe, expect, it } from 'vitest';
import { deriveOperationalHealth } from '../src/health/operational-health';

describe('P5A operational health projection', () => {
  it('raises explicit attention when the device is offline', () => {
    const health = deriveOperationalHealth(false);

    expect(health.connectivity).toBe('OFFLINE');
    expect(health.needsAttention).toBe(true);
    expect(health.title).toContain('Perlu perhatian');
    expect(health.detail).toContain('server');
  });

  it('does not raise attention merely because the device is online', () => {
    const health = deriveOperationalHealth(true);

    expect(health.connectivity).toBe('ONLINE');
    expect(health.needsAttention).toBe(false);
  });

  it('does not equate browser connectivity with backend health', () => {
    const health = deriveOperationalHealth(true);

    expect(health.detail).toContain('bukan pernyataan');
    expect(health.detail).toContain('backend');
    expect(health.detail).toContain('database');
  });
});
