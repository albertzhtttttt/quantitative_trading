#!/usr/bin/env bash
set -euo pipefail

# 从后端 .env 读取 PostgreSQL 连接信息，生成带时间戳的自包含 SQL 备份，并按天数清理旧备份。
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
ENV_FILE="${ENV_FILE:-${REPO_ROOT}/backend/.env}"
BACKUP_DIR="${BACKUP_DIR:-${REPO_ROOT}/backups/postgres}"
RETENTION_DAYS="${RETENTION_DAYS:-7}"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"

if [ ! -f "${ENV_FILE}" ]; then
  echo "未找到环境文件: ${ENV_FILE}" >&2
  exit 1
fi

# 只解析 PostgreSQL 所需字段，避免额外依赖 dotenv 工具。
DATABASE_URL="$(grep '^DATABASE_URL=' "${ENV_FILE}" | cut -d= -f2-)"
if [ -z "${DATABASE_URL}" ]; then
  echo "环境文件中缺少 DATABASE_URL" >&2
  exit 1
fi

python3 - <<'PY' "${DATABASE_URL}" "${BACKUP_DIR}" "${TIMESTAMP}" "${RETENTION_DAYS}"
import os
import re
import subprocess
import sys
from pathlib import Path
from urllib.parse import urlparse

url, backup_dir, timestamp, retention_days = sys.argv[1:5]
parsed = urlparse(url)
if parsed.scheme not in {"postgresql+psycopg", "postgresql"}:
    raise SystemExit(f"不支持的数据库类型: {parsed.scheme}")

backup_path = Path(backup_dir)
backup_path.mkdir(parents=True, exist_ok=True)
file_path = backup_path / f"postgres-{timestamp}.sql"

password = parsed.password or ""
env = os.environ.copy()
env["PGPASSWORD"] = password

command = [
    "pg_dump",
    "--host", parsed.hostname or "127.0.0.1",
    "--port", str(parsed.port or 5432),
    "--username", parsed.username or "postgres",
    "--dbname", parsed.path.lstrip("/"),
    "--clean",
    "--if-exists",
    "--create",
    "--file", str(file_path),
]
subprocess.run(command, env=env, check=True)
print(file_path)

cutoff_days = int(retention_days)
now = __import__('time').time()
pattern = re.compile(r"postgres-\d{8}-\d{6}\.sql$")
for item in backup_path.iterdir():
    if not pattern.match(item.name):
        continue
    age_days = (now - item.stat().st_mtime) / 86400
    if age_days > cutoff_days:
        item.unlink()
PY
