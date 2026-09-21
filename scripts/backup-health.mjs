import { createHash } from 'node:crypto';
import { existsSync, readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { pathToFileURL } from 'node:url';

export function sha256File(path) {
  const hash = createHash('sha256');
  hash.update(readFileSync(path));
  return hash.digest('hex');
}

function readJson(path, problems, label) {
  if (!existsSync(path)) {
    problems.push(label + ' tidak ditemukan: ' + path);
    return null;
  }

  try {
    return JSON.parse(readFileSync(path, 'utf8'));
  } catch {
    problems.push(label + ' bukan JSON valid: ' + path);
    return null;
  }
}

function validIsoDate(value) {
  return typeof value === 'string' && !Number.isNaN(Date.parse(value));
}

export function validateBackupBundle(bundleDir, retainedCopyPath) {
  const problems = [];
  const root = resolve(bundleDir);
  const manifestPath = resolve(root, 'backup-manifest.json');
  const restorePath = resolve(root, 'restore-verification.json');

  const manifest = readJson(manifestPath, problems, 'Manifest backup');
  const restore = readJson(restorePath, problems, 'Bukti restore');

  if (!manifest) {
    return { healthy: false, problems };
  }

  if (manifest.format_version !== 1) {
    problems.push('format_version backup harus 1.');
  }

  if (manifest.project_ref !== 'pkynjaqrxhhnnfuaxoqp') {
    problems.push(
      'project_ref backup tidak cocok dengan Segeran Jiwa POS Next.',
    );
  }

  if (!validIsoDate(manifest.created_at)) {
    problems.push('created_at manifest tidak valid.');
  }

  const exportFile = manifest.logical_export?.file;
  const expectedSha = manifest.logical_export?.sha256;

  if (typeof exportFile !== 'string' || exportFile.length === 0) {
    problems.push('logical_export.file wajib diisi.');
  }

  if (typeof expectedSha !== 'string' || !/^[0-9a-f]{64}$/i.test(expectedSha)) {
    problems.push('logical_export.sha256 wajib berupa SHA-256.');
  }

  let actualSha = null;
  if (typeof exportFile === 'string' && exportFile.length > 0) {
    const exportPath = resolve(root, exportFile);
    if (!exportPath.startsWith(root + '/') && exportPath !== root) {
      problems.push('logical_export.file tidak boleh keluar dari bundle.');
    } else if (!existsSync(exportPath)) {
      problems.push('Logical export tidak ditemukan: ' + exportPath);
    } else {
      actualSha = sha256File(exportPath);
      if (
        typeof expectedSha === 'string' &&
        actualSha.toLowerCase() !== expectedSha.toLowerCase()
      ) {
        problems.push('SHA-256 logical export tidak cocok dengan manifest.');
      }
    }
  }

  if (!retainedCopyPath) {
    problems.push('Retained copy di lokasi terpisah belum diberikan.');
  } else if (!existsSync(retainedCopyPath)) {
    problems.push('Retained copy tidak ditemukan: ' + retainedCopyPath);
  } else if (actualSha) {
    const retainedSha = sha256File(retainedCopyPath);
    if (retainedSha.toLowerCase() !== actualSha.toLowerCase()) {
      problems.push('SHA-256 retained copy tidak cocok dengan logical export.');
    }
  }

  if (restore) {
    if (restore.status !== 'PASS') {
      problems.push('Restore verification belum PASS.');
    }
    if (!validIsoDate(restore.verified_at)) {
      problems.push('verified_at restore verification tidak valid.');
    }
    if (!actualSha || restore.backup_sha256 !== actualSha) {
      problems.push(
        'restore-verification.json tidak terikat ke SHA-256 backup aktif.',
      );
    }
    if (
      typeof restore.method !== 'string' ||
      restore.method.trim().length === 0
    ) {
      problems.push('Metode restore verification wajib dicatat.');
    }
  }

  return {
    healthy: problems.length === 0,
    problems,
    backupSha256: actualSha,
  };
}

function main() {
  const [, , bundleDir, retainedCopyPath] = process.argv;

  if (!bundleDir) {
    console.error(
      'BACKUP_HEALTH=UNHEALTHY\nGunakan: node scripts/backup-health.mjs <bundle-dir> <retained-copy-file>',
    );
    process.exit(2);
  }

  const result = validateBackupBundle(bundleDir, retainedCopyPath);

  if (!result.healthy) {
    console.error('BACKUP_HEALTH=UNHEALTHY');
    for (const problem of result.problems) console.error('- ' + problem);
    process.exit(1);
  }

  console.log('BACKUP_HEALTH=HEALTHY');
  console.log('BACKUP_SHA256=' + result.backupSha256);
}

if (
  process.argv[1] &&
  import.meta.url === pathToFileURL(process.argv[1]).href
) {
  main();
}
