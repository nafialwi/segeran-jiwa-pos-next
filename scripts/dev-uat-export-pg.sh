#!/usr/bin/env bash
# F24 - operator-invoked, read-only Supabase DEV logical export.
# Never passes database password as argument or stores it in the repository.
set -Eeuo pipefail
umask 077

PROJECT=pkynjaqrxhhnnfuaxoqp
HOST=""
PORT=""
USER_NAME=""
DBNAME="postgres"
EXECUTE=NO
while (( $# )); do
  case "$1" in
    --host) HOST="${2:?missing host}"; shift 2 ;;
    --port) PORT="${2:?missing port}"; shift 2 ;;
    --user) USER_NAME="${2:?missing user}"; shift 2 ;;
    --dbname) DBNAME="${2:?missing database}"; shift 2 ;;
    --execute) EXECUTE=YES; shift ;;
    *) echo 'BACKUP_EXPORT=BLOCKED invalid argument'; exit 2 ;;
  esac
done

if [[ "$EXECUTE" != YES || -z "$HOST" || -z "$PORT" || -z "$USER_NAME" ]]; then
  echo "BACKUP_EXPORT=BLOCKED operator must pass --execute --host --port --user [--dbname]"
  exit 2
fi
if [[ ! "$PORT" =~ ^[0-9]{2,5}$ ]] || (( PORT < 1024 || PORT > 65535 )); then
  echo 'BACKUP_EXPORT=BLOCKED port invalid'
  exit 2
fi
if [[ ! "$DBNAME" =~ ^[A-Za-z_][A-Za-z0-9_]{0,62}$ ]]; then
  echo 'BACKUP_EXPORT=BLOCKED database name invalid'
  exit 2
fi
# Connection may use direct host or Supabase session pooler.
# Never accept another project's username as an accidental export target.
if [[ "$HOST" == "db.$PROJECT.supabase.co" ]]; then
  [[ "$USER_NAME" == postgres ]] || { echo 'BACKUP_EXPORT=BLOCKED direct user mismatch'; exit 2; }
elif [[ "$HOST" =~ ^[a-z0-9.-]+\.pooler\.supabase\.com$ ]]; then
  [[ "$USER_NAME" == "postgres.$PROJECT" ]] || {
    echo 'BACKUP_EXPORT=BLOCKED pooler user mismatch'
    exit 2
  }
else
  echo 'BACKUP_EXPORT=BLOCKED endpoint not recognized for Segeran Jiwa DEV'
  exit 2
fi

for tool in pg_dump pg_restore python3; do
  command -v "$tool" >/dev/null 2>&1 || {
    echo "BACKUP_EXPORT=BLOCKED missing=$tool"
    exit 2
  }
done

out_root="$HOME/WORKSTATION/BACKUPS/SEGERAN_JIWA_DEV_DB"
mkdir -p "$out_root"
stamp="$(date -u +%Y%m%dT%H%M%SZ)"
dir="$(mktemp -d "$out_root/backup-$stamp-XXXXXXXX")"
archive="$dir/backup.dump"
rm_partial() {
  rm -f -- "$archive.partial"
}
trap rm_partial EXIT

echo 'BACKUP_EXPORT=STARTING_READ_ONLY'
echo 'SCOPE=EXISTING_DEV_PROJECT'
echo 'PASSWORD=INTERACTIVE_PG_DUMP_PROMPT_NOT_STORED'
echo 'NOTE=THIS_EXPORT_WILL_NOT_AUTHORIZE_UAT_UNTIL_OFF_DEVICE_COPY_AND_RESTORE_VERIFIED'

# -W requests password without writing it to command history or output files.
# PGSSLMODE=require encrypts the database connection. Host certification is
# deployment-specific and should be verified using operator-provided CA chain.
(
  unset PGHOST PGHOSTADDR PGDATABASE PGPORT PGUSER PGPASSWORD PGPASSFILE PGSERVICE PGSERVICEFILE PGOPTIONS
  PGSSLMODE=require pg_dump \
    --host "$HOST" --port "$PORT" --username "$USER_NAME" --dbname "$DBNAME" \
    --format custom --no-owner --no-acl --file "$archive.partial" --password
)
[[ -s "$archive.partial" ]] || {
  echo 'BACKUP_EXPORT=FAILED archive empty'
  exit 1
}
mv -n -- "$archive.partial" "$archive"
pg_restore --list "$archive" >/dev/null
export SJPOS_F24_BUNDLE="$dir"
python3 - <<'PY'
import hashlib
import json
import os
from datetime import datetime, timezone
from pathlib import Path

root = Path(os.environ['SJPOS_F24_BUNDLE'])
archive = root / 'backup.dump'
digest = hashlib.file_digest(archive.open('rb'), 'sha256').hexdigest()
payload = {
    'format_version': 1,
    'project_ref': 'pkynjaqrxhhnnfuaxoqp',
    'created_at': datetime.now(timezone.utc).isoformat(timespec='seconds').replace('+00:00', 'Z'),
    'logical_export': {'file': 'backup.dump', 'sha256': digest},
}
(root / 'backup-manifest.json').write_text(json.dumps(payload, indent=2) + '\n')
PY
chmod 600 "$archive" "$dir/backup-manifest.json"
echo 'BACKUP_EXPORT=CREATED_BUT_UNVERIFIED'
echo "BUNDLE=$dir"
echo 'RETAINED_COPY=NOT_VERIFIED'
echo 'RESTORE_PROOF=NOT_VERIFIED'
echo 'UAT_MUTATIONS_ALLOWED=NO'
