#!/usr/bin/env bash
# C11-F24 — ephemeral, local-only PostgreSQL dump/restore rehearsal.
# Uses SYNTHETIC fixture data, never connects to hosted Supabase.
set -Eeuo pipefail
umask 077

for bin in initdb pg_ctl postgres createdb psql pg_dump pg_restore mktemp; do
  if ! command -v "$bin" >/dev/null 2>&1; then
    printf 'ISOLATED_RESTORE_SMOKE=BLOCKED missing=%s\n' "$bin"
    exit 2
  fi
done

# Safe temp directory must be in the local app-owned environment; not shared
# Android Download/DCIM and never in the application repository.
base="${TMPDIR:-/tmp}"
if [[ ! -w "$base" && -w /data/data/com.termux/files/usr/tmp ]]; then
  base=/data/data/com.termux/files/usr/tmp
fi
root="$(mktemp -d "$base/sjpos-pg-rehearsal-XXXXXXXX")"
chmod 700 "$root"
mkdir -m 700 "$root/socket"
stop_and_remove() {
  pg_ctl -D "$root/cluster" -m immediate -w stop >/dev/null 2>&1 || true
  rm -rf -- "$root"
}
trap stop_and_remove EXIT

initdb -D "$root/cluster" -U postgres \
  --auth-local=trust --auth-host=reject --no-instructions \
  >"$root/initdb.log" 2>&1

# Unix-domain socket only, no TCP listener, and only reachable in a private
# temp folder. Independent PostgreSQL cluster is deleted by the EXIT trap.
pg_ctl -D "$root/cluster" \
  -o "-c listen_addresses='' -c unix_socket_directories='$root/socket' -p 55439" \
  -l "$root/postgres.log" -w start >"$root/start.log" 2>&1

export PGHOST="$root/socket"
export PGPORT="55439"
export PGUSER="postgres"
unset PGPASSWORD PGPASSFILE PGSERVICE PGSERVICEFILE PGHOSTADDR PGOPTIONS PGDATABASE
createdb fixture_src
psql -X -v ON_ERROR_STOP=1 -d fixture_src -q <<'SQL'
CREATE TABLE public.synthetic_sales (
  id integer PRIMARY KEY,
  amount integer NOT NULL CHECK (amount > 0)
);
INSERT INTO public.synthetic_sales(id, amount)
VALUES (1, 1000), (2, 3500);
SQL

pg_dump -Fc --no-owner --no-acl -f "$root/fixture.dump" fixture_src
pg_restore --list "$root/fixture.dump" >"$root/archive-toc.txt"
createdb fixture_restored
pg_restore --exit-on-error --no-owner --no-acl \
  -d fixture_restored "$root/fixture.dump"

count="$(psql -XAt -d fixture_restored -c 'SELECT count(*) FROM public.synthetic_sales')"
amount="$(psql -XAt -d fixture_restored -c 'SELECT sum(amount) FROM public.synthetic_sales')"
if [[ "$count" != "2" || "$amount" != "4500" ]]; then
  printf 'ISOLATED_RESTORE_SMOKE=FAIL verified_count=%s verified_amount=%s\n' "$count" "$amount"
  exit 1
fi
printf 'ISOLATED_RESTORE_SMOKE=PASS\n'
printf 'FIXTURE_ROWS_RESTORED=%s\n' "$count"
printf 'FIXTURE_SUM_VERIFIED=%s\n' "$amount"
printf 'HOSTED_SUPABASE_CONTACTED=NO\n'
printf 'TCP_LISTENER_ENABLED=NO\n'
printf 'CLUSTER_REMOVED_ON_EXIT=YES\n'
