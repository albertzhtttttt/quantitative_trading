#!/usr/bin/env bash
set -euo pipefail

# 在服务器上安装 PostgreSQL 备份的 systemd service/timer；默认每天凌晨 03:45 执行一次。
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
APP_ROOT="${APP_ROOT:-/opt/quantitative_trading}"
SYSTEMD_DIR="${SYSTEMD_DIR:-/etc/systemd/system}"
BACKUP_DIR="${BACKUP_DIR:-${APP_ROOT}/backups/postgres}"
RETENTION_DAYS="${RETENTION_DAYS:-7}"
ON_CALENDAR="${ON_CALENDAR:-*-*-* 03:45:00}"

mkdir -p "${APP_ROOT}/scripts" "${BACKUP_DIR}"
SOURCE_SCRIPT="${REPO_ROOT}/scripts/backup_postgres.sh"
TARGET_SCRIPT="${APP_ROOT}/scripts/backup_postgres.sh"
if [ "$(realpath "${SOURCE_SCRIPT}")" != "$(realpath -m "${TARGET_SCRIPT}")" ]; then
  cp "${SOURCE_SCRIPT}" "${TARGET_SCRIPT}"
fi
chmod +x "${TARGET_SCRIPT}"

cat > "${SYSTEMD_DIR}/quant-postgres-backup.service" <<EOF
[Unit]
Description=Quantitative Trading PostgreSQL Backup
After=postgresql.service
Wants=postgresql.service

[Service]
Type=oneshot
WorkingDirectory=${APP_ROOT}
Environment=ENV_FILE=${APP_ROOT}/backend/.env
Environment=BACKUP_DIR=${BACKUP_DIR}
Environment=RETENTION_DAYS=${RETENTION_DAYS}
ExecStart=${APP_ROOT}/scripts/backup_postgres.sh
EOF

cat > "${SYSTEMD_DIR}/quant-postgres-backup.timer" <<EOF
[Unit]
Description=Run Quantitative Trading PostgreSQL backup daily

[Timer]
OnCalendar=${ON_CALENDAR}
Persistent=true
Unit=quant-postgres-backup.service

[Install]
WantedBy=timers.target
EOF

systemctl daemon-reload
systemctl enable --now quant-postgres-backup.timer
systemctl start quant-postgres-backup.service
systemctl is-active quant-postgres-backup.timer >/dev/null
systemctl status quant-postgres-backup.service --no-pager -n 20 || true
systemctl status quant-postgres-backup.timer --no-pager -n 20 || true
