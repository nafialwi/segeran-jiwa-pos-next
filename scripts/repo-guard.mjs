import { execFileSync } from 'node:child_process';
import { pathToFileURL } from 'node:url';

export function findForbiddenTrackedPaths(paths) {
  return paths.filter((path) => {
    const lower = path.toLowerCase();
    if (lower === '.env.example') return false;
    if (lower === '.env' || lower.startsWith('.env.')) return true;
    return (
      lower.includes('secret') ||
      lower.endsWith('.pem') ||
      lower.endsWith('.key') ||
      lower.endsWith('.p12') ||
      lower.endsWith('.pfx')
    );
  });
}

function main() {
  const tracked = execFileSync('git', ['ls-files'], {
    encoding: 'utf8',
  })
    .split('\n')
    .filter(Boolean);

  const violations = findForbiddenTrackedPaths(tracked);
  if (violations.length > 0) {
    console.error('Forbidden tracked paths:');
    for (const path of violations) console.error(`- ${path}`);
    process.exit(1);
  }
}

if (import.meta.url === pathToFileURL(process.argv[1]).href) {
  main();
}
