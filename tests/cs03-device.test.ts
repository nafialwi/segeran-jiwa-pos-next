import { describe, expect, it } from 'vitest';
import {
  getDeviceKind,
  getOrCreateDeviceId,
  getRememberedUsernames,
  rememberUsername,
  setDeviceKind,
} from '../src/auth/device';

class MemoryStorage implements Storage {
  private readonly data = new Map<string, string>();

  get length(): number {
    return this.data.size;
  }

  clear(): void {
    this.data.clear();
  }

  getItem(key: string): string | null {
    return this.data.get(key) ?? null;
  }

  key(index: number): string | null {
    return [...this.data.keys()][index] ?? null;
  }

  removeItem(key: string): void {
    this.data.delete(key);
  }

  setItem(key: string, value: string): void {
    this.data.set(key, value);
  }

  entries(): Array<[string, string]> {
    return [...this.data.entries()];
  }
}

describe('CS-03 local device contract', () => {
  it('creates one UUID and reuses it on later calls', () => {
    const storage = new MemoryStorage();
    const first = getOrCreateDeviceId(storage);
    const second = getOrCreateDeviceId(storage);

    expect(first).toMatch(
      /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i,
    );
    expect(second).toBe(first);
  });

  it('defaults to PERSONAL and persists SHARED when selected', () => {
    const storage = new MemoryStorage();

    expect(getDeviceKind(storage)).toBe('PERSONAL');
    setDeviceKind(storage, 'SHARED');
    expect(getDeviceKind(storage)).toBe('SHARED');
  });

  it('normalizes, de-duplicates and caps remembered usernames at eight', () => {
    const storage = new MemoryStorage();

    for (let index = 1; index <= 10; index += 1) {
      rememberUsername(storage, ` Kasir_${index} `);
    }
    rememberUsername(storage, 'KASIR_8');

    const remembered = getRememberedUsernames(storage);
    expect(remembered).toHaveLength(8);
    expect(remembered[0]).toBe('kasir_8');
    expect(new Set(remembered).size).toBe(8);
    expect(remembered).not.toContain('kasir_1');
    expect(remembered).not.toContain('kasir_2');
  });

  it('never writes password or token storage fields', () => {
    const storage = new MemoryStorage();

    getOrCreateDeviceId(storage);
    setDeviceKind(storage, 'PERSONAL');
    rememberUsername(storage, 'kasir1');

    const serialized = JSON.stringify(storage.entries()).toLowerCase();
    expect(serialized).not.toContain('password');
    expect(serialized).not.toContain('token');
  });
});
