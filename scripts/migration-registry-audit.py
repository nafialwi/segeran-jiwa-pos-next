#!/usr/bin/env python3
"""F25 read-only migration registry inventory, not a SQL equivalence proof."""
import argparse
from collections import Counter
import json
from pathlib import Path
import re
import sys

EXPECTED_REF = 'pkynjaqrxhhnnfuaxoqp'
FILENAME = re.compile(r'^(\d{14})_([a-z][a-z0-9_]+)\.sql$')
NAME = re.compile(r'^[a-z][a-z0-9_]+$')
VERSION = re.compile(r'^\d{14}$')


def local_history(directory):
    root = Path(directory)
    if not root.is_dir():
        raise ValueError('LOCAL_MIGRATIONS_NOT_FOUND')
    entries = []
    for path in sorted(root.glob('*.sql')):
        match = FILENAME.fullmatch(path.name)
        if not match:
            raise ValueError('INVALID_LOCAL_MIGRATION_FILENAME')
        entries.append({'version': match.group(1), 'name': match.group(2)})
    if not entries:
        raise ValueError('LOCAL_MIGRATIONS_EMPTY')
    return entries


def remote_history(filename):
    payload = json.loads(Path(filename).read_text(encoding='utf-8'))
    if payload.get('project_ref') != EXPECTED_REF:
        raise ValueError('REMOTE_PROJECT_REF_INVALID')
    values = payload.get('migrations')
    if not isinstance(values, list) or not values:
        raise ValueError('REMOTE_HISTORY_EMPTY')
    result = []
    for item in values:
        if not isinstance(item, dict):
            raise ValueError('REMOTE_ENTRY_INVALID')
        v, n = item.get('version'), item.get('name')
        if not isinstance(v, str) or not VERSION.fullmatch(v):
            raise ValueError('REMOTE_VERSION_INVALID')
        if not isinstance(n, str) or not NAME.fullmatch(n):
            raise ValueError('REMOTE_NAME_INVALID')
        result.append({'version': v, 'name': n})
    return result


def audit(local, remote):
    lv = {i['version']: i['name'] for i in local}
    rv = {i['version']: i['name'] for i in remote}
    if len(lv) != len(local) or len(rv) != len(remote):
        raise ValueError('DUPLICATE_VERSION_INVALID')
    ln = {x['name'] for x in local}
    rn = {x['name'] for x in remote}
    lc, rc = Counter(x['name'] for x in local), Counter(x['name'] for x in remote)
    exact = [i for i in remote if lv.get(i['version']) == i['name']]
    same_name_new_version = [
        {'name': i['name'], 'remote_version': i['version'],
         'local_versions': sorted(x['version'] for x in local if x['name'] == i['name'])}
        for i in remote if i['name'] in ln and lv.get(i['version']) != i['name']
    ]
    same_version_different_name = [
        {'version': i['version'], 'remote_name': i['name'], 'local_name': lv[i['version']]}
        for i in remote if i['version'] in lv and lv[i['version']] != i['name']
    ]
    remote_only_names = sorted((i for i in remote if i['name'] not in ln),
                               key=lambda x: (x['name'], x['version']))
    local_only_names = sorted((i for i in local if i['name'] not in rn),
                              key=lambda x: (x['name'], x['version']))
    repeated_remote = {name: count for name, count in rc.items() if count > 1}
    repeated_local = {name: count for name, count in lc.items() if count > 1}
    return {
        'status': 'MANUAL_RECONCILIATION_REQUIRED',
        'project_ref': EXPECTED_REF,
        'local_file_count': len(local),
        'remote_registry_count': len(remote),
        'exact_version_and_name_count': len(exact),
        'name_matched_other_version_count': len(same_name_new_version),
        'remote_without_local_name_count': len(remote_only_names),
        'local_without_remote_name_count': len(local_only_names),
        'duplicate_remote_names': repeated_remote,
        'duplicate_local_names': repeated_local,
        'same_version_different_name': same_version_different_name,
        'name_matched_other_version': same_name_new_version,
        'remote_without_local_name': remote_only_names,
        'local_without_remote_name': local_only_names,
        'no_sql_equivalence_claim': True,
        'safe_to_automatically_push_migrations': False,
        'safe_to_reset_database': False,
    }


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--local-dir', default='supabase/migrations')
    parser.add_argument('--remote-registry', required=True)
    opts = parser.parse_args()
    try:
        result = audit(local_history(opts.local_dir),
                       remote_history(opts.remote_registry))
    except (OSError, ValueError, json.JSONDecodeError) as exc:
        print(json.dumps({'status': 'BLOCKED', 'reason': str(exc),
                          'safe_to_automatically_push_migrations': False}))
        return 2
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 0


if __name__ == '__main__':
    sys.exit(main())
