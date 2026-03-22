#!/usr/bin/env bash
set -euo pipefail

# 把 PostgreSQL 恢复演练固化成一条可重复执行的流程：
# 1. 自动挑选或接收一份备份文件
# 2. 恢复到临时校验库
# 3. 校验关键表和管理员数据是否存在
# 4. 清理临时校验库
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
ENV_FILE="${ENV_FILE:-${REPO_ROOT}/backend/.env}"
BACKUP_FILE="${1:-}"
RESTORE_DATABASE="${RESTORE_DATABASE:-quantitative_trading_restore_check}"
KEEP_RESTORE_DB="${KEEP_RESTORE_DB:-0}"

if [ ! -f "${ENV_FILE}" ]; then
  echo "未找到环境文件: ${ENV_FILE}" >&2
  exit 1
fi

if [ -z "${BACKUP_FILE}" ]; then
  BACKUP_FILE="$(python3 - <<'PY' "${REPO_ROOT}"
import sys
from pathlib import Path

repo_root = Path(sys.argv[1])
backup_dir = repo_root / 'backups' / 'postgres'
files = sorted(backup_dir.glob('postgres-*.sql'))
if not files:
    raise SystemExit('未找到任何 PostgreSQL 备份文件，请显式传入备份路径。')
print(files[-1])
PY
)"
fi

if [ ! -f "${BACKUP_FILE}" ]; then
  echo "未找到备份文件: ${BACKUP_FILE}" >&2
  exit 1
fi

DATABASE_URL="$(grep '^DATABASE_URL=' "${ENV_FILE}" | cut -d= -f2-)"
if [ -z "${DATABASE_URL}" ]; then
  echo "环境文件中缺少 DATABASE_URL" >&2
  exit 1
fi

TARGET_DATABASE="${RESTORE_DATABASE}" bash "${SCRIPT_DIR}/restore_postgres.sh" "${BACKUP_FILE}"

python3 - <<'PY' "${DATABASE_URL}" "${RESTORE_DATABASE}" "${KEEP_RESTORE_DB}"
import os
import subprocess
import sys
from urllib.parse import urlparse

url, restore_database, keep_restore_db = sys.argv[1:4]
parsed = urlparse(url)
if parsed.scheme not in {"postgresql+psycopg", "postgresql"}:
    raise SystemExit(f"不支持的数据库类型: {parsed.scheme}")

password = parsed.password or ""
env = os.environ.copy()
env["PGPASSWORD"] = password
base_command = [
    "psql",
    "-X",
    "--set",
    "ON_ERROR_STOP=1",
    "--host",
    parsed.hostname or "127.0.0.1",
    "--port",
    str(parsed.port or 5432),
    "--username",
    parsed.username or "postgres",
    "--dbname",
    restore_database,
    "-Atqc",
]

def query(sql: str) -> str:
    result = subprocess.run(base_command + [sql], env=env, check=True, capture_output=True, text=True)
    return result.stdout.strip()

user_count = query("SELECT count(*) FROM public.users;")
admin_name = query("SELECT username FROM public.users ORDER BY id LIMIT 1;")
print(f"恢复校验通过: users={user_count}, first_user={admin_name}")

if keep_restore_db != "1":
    drop_command = [
        "psql",
        "-X",
        "--set",
        "ON_ERROR_STOP=1",
        "--host",
        parsed.hostname or "127.0.0.1",
        "--port",
        str(parsed.port or 5432),
        "--username",
        parsed.username or "postgres",
        "--dbname",
        "postgres",
        "-c",
        f"DROP DATABASE {restore_database};",
    ]
    subprocess.run(drop_command, env=env, check=True)
    print(f"已清理临时恢复库: {restore_database}")
PY
