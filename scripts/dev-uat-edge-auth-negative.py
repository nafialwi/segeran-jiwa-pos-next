#!/usr/bin/env python3
"""F24 read-only auth negative test for dev Edge Functions.

Makes ONLY non-authorized POST requests with an intentionally invalid action.
Never sends actual user tokens and never prints API keys or response headers.
"""
import argparse
import json
from pathlib import Path
import sys
import urllib.error
import urllib.request

PROJECT_REF = 'pkynjaqrxhhnnfuaxoqp'
FUNCTIONS = ('identity-admin', 'device-admin')
ACTION = '__f24_auth_denial_probe__'


def read_dev_config(path):
    entries = {}
    for line in Path(path).read_text(encoding='utf-8').splitlines():
        if not line.strip() or line.lstrip().startswith('#') or '=' not in line:
            continue
        key, val = line.split('=', 1)
        entries[key.strip()] = val.strip().strip("\"'")
    url = entries.get('VITE_SUPABASE_URL', '').rstrip('/')
    key = entries.get('VITE_SUPABASE_PUBLISHABLE_KEY') or entries.get('VITE_SUPABASE_ANON_KEY')
    if url != f'https://{PROJECT_REF}.supabase.co' or not key:
        raise ValueError('DEV_PROJECT_OR_PUBLISHABLE_KEY_NOT_VERIFIED')
    if key.startswith('sb_secret_') or key.startswith('service_role'):
        raise ValueError('SERVER_KEY_MUST_NEVER_BE_SENT_BY_BROWSER_TEST')
    return url, key


def post_negative(url, key, function, with_invalid_bearer=False):
    headers = {'Content-Type': 'application/json', 'apikey': key}
    if with_invalid_bearer:
        headers['Authorization'] = 'Bearer intentionally-invalid-f24-token'
    request = urllib.request.Request(
        f'{url}/functions/v1/{function}',
        data=json.dumps({'action': ACTION}).encode('utf-8'),
        headers=headers, method='POST',
    )
    try:
        with urllib.request.urlopen(request, timeout=12) as response:
            status = response.status
            body = response.read(1600)
    except urllib.error.HTTPError as error:
        status = error.code
        body = error.read(1600)
    try:
        payload = json.loads(body)
        detail = payload.get('error', payload) if isinstance(payload, dict) else {}
        code = detail.get('code', '') if isinstance(detail, dict) else ''
    except (ValueError, AttributeError):
        code = ''
    return status, code


def run(path):
    url, key = read_dev_config(path)
    passed = 0
    for function in FUNCTIONS:
        for has_bad_bearer in (False, True):
            status, code = post_negative(url, key, function, has_bad_bearer)
            result = 'PASS' if (status == 401 and code == 'SJ_AUTH_REQUIRED') else 'FAIL'
            print(f'{function} ' +
                  ('invalid_bearer' if has_bad_bearer else 'missing_bearer') +
                  f' HTTP={status} AUTH_DENIED={result}', flush=True)
            if result != 'PASS':
                return 1
            passed += 1
    print(f'F24_LIVE_NEGATIVE_AUTH=PASS checks={passed}', flush=True)
    return 0


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Development Edge Function deny-only check')
    parser.add_argument('--dev-env', default='.env')
    parser.add_argument('--live', action='store_true',
                        help='explicitly authorize only the four safe negative-auth calls')
    args = parser.parse_args()
    if not args.live:
        print('F24_LIVE_NEGATIVE_AUTH=BLOCKED explicit --live required')
        sys.exit(2)
    try:
        sys.exit(run(args.dev_env))
    except (OSError, ValueError, urllib.error.URLError) as exc:
        print('F24_LIVE_NEGATIVE_AUTH=INCONCLUSIVE ' + type(exc).__name__)
        sys.exit(2)
