#!/usr/bin/env python3
"""Read-only-in-effect negative authentication regression for 4 XP RPCs.

The stored server definitions first call authorize_agent, which raises 28000
when the x-agent-token header is absent. This client never supplies that header.
Never run against an unreviewed endpoint, or with a real agent identity.
"""
import argparse
import json
from pathlib import Path
import sys
import urllib.error
import urllib.request

EXPECTED_PROJECT = 'pkynjaqrxhhnnfuaxoqp'
FAKE_AGENT = '__F25_UNREGISTERED_NO_TOKEN__'
FAKE_UUID = '00000000-0000-4000-8000-000000000001'
BODIES = {
    'xp_agent_heartbeat_v2': {'p_agent_id': FAKE_AGENT},
    'xp_claim_job_v2': {'p_agent_id': FAKE_AGENT, 'p_lease_seconds': 300},
    'xp_finish_job_v2': {'p_agent_id': FAKE_AGENT,
                         'p_job_id': FAKE_UUID, 'p_return_code': 1},
    'xp_renew_job_v2': {'p_agent_id': FAKE_AGENT,
                        'p_job_id': FAKE_UUID, 'p_lease_seconds': 300},
}


def read_public_dev_settings(path):
    opts = {}
    for line in Path(path).read_text(encoding='utf-8').splitlines():
        if '=' in line and not line.lstrip().startswith('#'):
            name, value = line.split('=', 1)
            opts[name.strip()] = value.strip().strip("\"'")
    base = opts.get('VITE_SUPABASE_URL', '').rstrip('/')
    key = opts.get('VITE_SUPABASE_PUBLISHABLE_KEY') or opts.get('VITE_SUPABASE_ANON_KEY')
    if base != 'https://' + EXPECTED_PROJECT + '.supabase.co' or not key:
        raise ValueError('DEV_PROJECT_OR_PUBLIC_KEY_UNVERIFIED')
    if key.startswith(('sb_secret_', 'service_role')):
        raise ValueError('SECRET_KEY_NOT_ACCEPTED')
    return base, key


def check_rpc(base, public_key, function, arguments):
    request = urllib.request.Request(
        f'{base}/rest/v1/rpc/{function}',
        data=json.dumps(arguments).encode(),
        headers={'apikey': public_key, 'Content-Type': 'application/json'},
        method='POST',
    )
    try:
        with urllib.request.urlopen(request, timeout=12) as response:
            status = response.status
            body = response.read(1200)
    except urllib.error.HTTPError as error:
        status = error.code
        body = error.read(1200)
    try:
        payload = json.loads(body)
        error_code = payload.get('code') if isinstance(payload, dict) else None
    except (ValueError, AttributeError):
        error_code = None
    return status, error_code


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--dev-env', default='.env')
    parser.add_argument('--live', action='store_true')
    args = parser.parse_args()
    if not args.live:
        print('F25_XP_ANON_NEGATIVE=BLOCKED (--live required)')
        return 2
    try:
        base, key = read_public_dev_settings(args.dev_env)
        for function, body in BODIES.items():
            status, code = check_rpc(base, key, function, body)
            ok = status == 403 and str(code) == '28000'
            print(f'{function} HTTP={status} SQLSTATE={code} DENIED={ok}')
            if not ok:
                print('F25_XP_ANON_NEGATIVE=FAIL')
                return 1
        print('F25_XP_ANON_NEGATIVE=PASS checks=4')
        return 0
    except (OSError, ValueError, urllib.error.URLError) as exc:
        print('F25_XP_ANON_NEGATIVE=INCONCLUSIVE ' + type(exc).__name__)
        return 2


if __name__ == '__main__':
    sys.exit(main())
