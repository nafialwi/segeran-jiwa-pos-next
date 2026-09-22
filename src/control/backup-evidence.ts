export const BACKUP_CHECKPOINT_EVIDENCE = {
  evidenceKind: 'VERIFIED_CHECKPOINT',
  verifiedAt: '2026-09-21T00:00:00+07:00',
  projectRef: 'pkynjaqrxhhnnfuaxoqp',
  verdict: 'LOCKED_REMOTE',
  backupGate: 'HEALTHY',
  restoreStatus: 'PASS',
  restoreMethod: 'isolated PostgreSQL 18.6 restore',
  archiveTocEntries: 1210,
  restoredCounts: {
    businesses: 1,
    profiles: 1,
    stockItems: 68,
    sales: 6,
    authUsers: 1,
    schemaVersions: 3,
  },
  note: 'Bukti checkpoint P5C. Ini bukan status backup realtime dan tidak membuktikan backup terbaru masih valid.',
} as const;

export function backupEvidenceAgeDays(now = new Date()): number {
  const verified = new Date(BACKUP_CHECKPOINT_EVIDENCE.verifiedAt);
  return Math.max(
    0,
    Math.floor((now.getTime() - verified.getTime()) / (24 * 60 * 60 * 1000)),
  );
}
