#!/usr/bin/env bash
set -euo pipefail

# 使用后端 .env 中的 PostgreSQL 凭据恢复指定 SQL 备份；默认要求显式传入备份文件路径。
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
ENV_FILE="${ENV_FILE:-${REPO_ROOT}/backend/.env}"
BACKUP_FILE="${1:-}"

if [ -z "${BACKUP_FILE}" ]; then
  echo "用法: bash scripts/restore_postgres.sh <backup-file>" >&2
  exit 1
fi

if [ ! -f "${ENV_FILE}" ]; then
  echo "未找到环境文件: ${ENV_FILE}" >&2
  exit 1
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

python3 - <<'PY' "${DATABASE_URL}" "${BACKUP_FILE}"
import os
import subprocess
import sys
from urllib.parse import urlparse

url, backup_file = sys.argv[1:3]
parsed = urlparse(url)
if parsed.scheme not in {"postgresql+psycopg", "postgresql"}:
    raise SystemExit(f"不支持的数据库类型: {parsed.scheme}")

env = os.environ.copy()
env["PGPASSWORD"] = parsed.password or ""
command = [
    "psql",
    "--host", parsed.hostname or "127.0.0.1",
    "--port", str(parsed.port or 5432),
    "--username", parsed.username or "postgres",
    "--dbname", "postgres",
    "--file", backup_file,
]
subprocess.run(command, env=env, check=True)
PY
