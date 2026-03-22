#!/usr/bin/env bash
set -euo pipefail

# 使用后端 .env 中的 PostgreSQL 凭据恢复指定 SQL 备份。
# 默认拒绝直接覆盖生产数据库，避免误把演练操作打到线上；
# 如需真实恢复，请显式设置 ALLOW_PRODUCTION_RESTORE=1。
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
ENV_FILE="${ENV_FILE:-${REPO_ROOT}/backend/.env}"
BACKUP_FILE="${1:-}"
TARGET_DATABASE="${TARGET_DATABASE:-}"
ALLOW_PRODUCTION_RESTORE="${ALLOW_PRODUCTION_RESTORE:-0}"

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

python3 - <<'PY' "${DATABASE_URL}" "${BACKUP_FILE}" "${TARGET_DATABASE}" "${ALLOW_PRODUCTION_RESTORE}"
import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path
from urllib.parse import urlparse

url, backup_file, target_database, allow_production_restore = sys.argv[1:5]
parsed = urlparse(url)
if parsed.scheme not in {"postgresql+psycopg", "postgresql"}:
    raise SystemExit(f"不支持的数据库类型: {parsed.scheme}")

original_database = parsed.path.lstrip("/")
if not original_database:
    raise SystemExit("DATABASE_URL 中缺少数据库名")

if target_database and not re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", target_database):
    raise SystemExit("TARGET_DATABASE 仅支持字母、数字和下划线，且不能以数字开头")

if not target_database:
    target_database = original_database

if target_database == original_database and allow_production_restore != "1":
    raise SystemExit(
        "默认拒绝直接覆盖生产数据库；如确认要恢复线上库，请设置 ALLOW_PRODUCTION_RESTORE=1，"
        "或通过 TARGET_DATABASE 指定临时数据库进行恢复演练。"
    )

backup_path = Path(backup_file)
restore_file = backup_path
transformed_file: Path | None = None

# 当目标库名与备份中的原始库名不一致时，按行重写建库与连接语句，
# 这样可以把同一份 SQL 备份安全恢复到临时校验库，而不影响生产库。
def rewrite_line(line: str) -> str:
    if re.fullmatch(rf"DROP DATABASE IF EXISTS {re.escape(original_database)};", line):
        return f"DROP DATABASE IF EXISTS {target_database};"

    create_match = re.fullmatch(rf"CREATE DATABASE {re.escape(original_database)}( .+;)", line)
    if create_match:
        return f"CREATE DATABASE {target_database}{create_match.group(1)}"

    alter_match = re.fullmatch(rf"ALTER DATABASE {re.escape(original_database)}( .+;)", line)
    if alter_match:
        return f"ALTER DATABASE {target_database}{alter_match.group(1)}"

    if re.fullmatch(rf"\\connect {re.escape(original_database)}", line):
        return f"\\connect {target_database}"

    return line

# 备份中包含 DROP/CREATE DATABASE 和 OWNER 变更；
# 在服务器以 root 执行时优先切到本机 postgres 超级用户恢复，避免普通业务账号因缺少 CREATEDB 权限而失败。
def can_use_local_postgres_superuser() -> bool:
    if os.name != "posix":
        return False
    if not hasattr(os, "geteuid") or os.geteuid() != 0:
        return False
    if shutil.which("sudo") is None:
        return False

    probe = subprocess.run(
        ["sudo", "-u", "postgres", "psql", "--dbname", "postgres", "-Atqc", "SELECT 1"],
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
        text=True,
        check=False,
    )
    return probe.returncode == 0 and probe.stdout.strip() == "1"

try:
    if target_database != original_database:
        with tempfile.NamedTemporaryFile("w", delete=False, encoding="utf-8", newline="\n") as handle:
            transformed_file = Path(handle.name)
            with backup_path.open("r", encoding="utf-8") as source:
                for raw_line in source:
                    handle.write(rewrite_line(raw_line.rstrip("\n")) + "\n")
        transformed_file.chmod(0o644)
        restore_file = transformed_file

    env = os.environ.copy()
    if can_use_local_postgres_superuser():
        command = [
            "sudo",
            "-u",
            "postgres",
            "psql",
            "-X",
            "--set",
            "ON_ERROR_STOP=1",
            "--dbname",
            "postgres",
            "--file",
            str(restore_file),
        ]
    else:
        env["PGPASSWORD"] = parsed.password or ""
        command = [
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
            "--file",
            str(restore_file),
        ]
    subprocess.run(command, env=env, check=True)
    print(f"已恢复到数据库: {target_database}")
finally:
    if transformed_file and transformed_file.exists():
        transformed_file.unlink()
PY
