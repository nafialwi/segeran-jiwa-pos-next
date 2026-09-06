import { describe, expect, it } from 'vitest';
import { readFileSync } from 'node:fs';

function read(path) {
  return readFileSync(new URL(`../${path}`, import.meta.url), 'utf8');
}

describe('Android-first runbooks', () => {
  it('locks the normal Android mobile-inbox workflow', () => {
    const source = read('docs/runbooks/MOBILE_INBOX.md');

    expect(source.startsWith('Normal workflow — Android browser\n')).toBe(true);

    const requiredInOrder = [
      'Buka repository Segeran Jiwa POS Next di GitHub melalui browser HP.',
      'Pilih branch mobile-inbox.',
      'Buka folder inbox.',
      'Pilih Add file → Upload files.',
      'Pilih tepat satu ZIP package untuk milestone aktif.',
      'Commit upload ke mobile-inbox.',
      'Buka Actions/PR hanya untuk melihat hasil.',
      'Jika Preview sudah tersedia, lakukan QA di HP.',
      'Berikan approval milestone hanya setelah hasil sesuai.',
    ];

    let cursor = -1;
    for (const token of requiredInOrder) {
      const next = source.indexOf(token);
      expect(next).toBeGreaterThan(cursor);
      cursor = next;
    }

    expect(source).toContain('Jangan pernah upload ZIP transit ke `main`.');
    expect(source).toContain(
      'Upload package tidak boleh mempromosikan Production.',
    );
    expect(source).toContain('Jangan edit manual branch `work/**`');
    expect(source).toContain('retry_safe: true');
    expect(source).toContain('idempotent no-op');
  });

  it('locks the recovery order and does not jump straight to Termux', () => {
    const source = read('docs/runbooks/RECOVERY.md');

    expect(source).toContain(
      'Mobile Inbox Automation\n→ Codespaces debugging\n→ manual GitHub transfer branch\n→ Termux/X11\n→ PC',
    );
    expect(source).toContain(
      'Satu Action run gagal **bukan** alasan otomatis pindah ke Termux.',
    );
    expect(source).toContain(
      'Jangan gunakan `main` sebagai tempat transit ZIP.',
    );
  });

  it('carries exact continuity snapshots from the final handoff', () => {
    const workflow = read('docs/blueprint/15_WORKFLOW_PROFILE.md');
    const state = read(
      'docs/checkpoints/17_PROJECT_STATE_BP_LOCKED_SNAPSHOT.md',
    );
    const checkpoint = read(
      'docs/checkpoints/18_CHECKPOINT_REPORT_TEMPLATE.md',
    );

    expect(workflow).toContain('# WORKFLOW PROFILE — Segeran Jiwa POS Next');
    expect(workflow).toContain('Android phone + browser');
    expect(workflow).toContain('Manual GitHub transfer branch');

    expect(state).toContain('# PROJECT STATE — 6 September 2026');
    expect(state).toContain('BP-LOCKED — Blueprint Final v1.0');

    expect(checkpoint).toContain('# CHECKPOINT REPORT TEMPLATE');
    expect(checkpoint).toContain('## NEXT ACTION');
  });
});
