#!/usr/bin/env bash
set -euo pipefail

# 在服务器上安装运行时健康检查的 systemd service/timer，
# 定时从本机 HTTPS 入口校验前端页面、Nginx 反向代理和后端 ready 状态，
# 并把结果写入独立日志文件，再交给 logrotate 控制体积。
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
APP_ROOT="${APP_ROOT:-/opt/quantitative_trading}"
SYSTEMD_DIR="${SYSTEMD_DIR:-/etc/systemd/system}"
LOG_DIR="${LOG_DIR:-/var/log/quantitative_trading}"
LOGROTATE_FILE="${LOGROTATE_FILE:-/etc/logrotate.d/quantitative_trading}"
ON_BOOT_SEC="${ON_BOOT_SEC:-2min}"
ON_UNIT_ACTIVE_SEC="${ON_UNIT_ACTIVE_SEC:-5min}"

mkdir -p "${APP_ROOT}/scripts" "${LOG_DIR}"
SOURCE_SCRIPT="${REPO_ROOT}/scripts/check_runtime_health.sh"
TARGET_SCRIPT="${APP_ROOT}/scripts/check_runtime_health.sh"
if [ "$(realpath "${SOURCE_SCRIPT}")" != "$(realpath -m "${TARGET_SCRIPT}")" ]; then
  cp "${SOURCE_SCRIPT}" "${TARGET_SCRIPT}"
fi
RUNNER_SOURCE_SCRIPT="${REPO_ROOT}/scripts/run_runtime_health_check.sh"
RUNNER_TARGET_SCRIPT="${APP_ROOT}/scripts/run_runtime_health_check.sh"
if [ "$(realpath "${RUNNER_SOURCE_SCRIPT}")" != "$(realpath -m "${RUNNER_TARGET_SCRIPT}")" ]; then
  cp "${RUNNER_SOURCE_SCRIPT}" "${RUNNER_TARGET_SCRIPT}"
fi
chmod +x "${TARGET_SCRIPT}" "${RUNNER_TARGET_SCRIPT}"

cat > "${SYSTEMD_DIR}/quant-runtime-health.service" <<EOF
[Unit]
Description=Quantitative Trading Runtime Health Check
After=nginx.service quant-backend.service quant-frontend.service postgresql.service redis-server.service
Wants=nginx.service quant-backend.service quant-frontend.service postgresql.service redis-server.service

[Service]
Type=oneshot
WorkingDirectory=${APP_ROOT}
Environment=LOG_DIR=${LOG_DIR}
ExecStart=${APP_ROOT}/scripts/run_runtime_health_check.sh
StandardOutput=append:${LOG_DIR}/runtime-health.log
StandardError=append:${LOG_DIR}/runtime-health.log
EOF

cat > "${SYSTEMD_DIR}/quant-runtime-health.timer" <<EOF
[Unit]
Description=Run Quantitative Trading runtime health check periodically

[Timer]
OnBootSec=${ON_BOOT_SEC}
OnUnitActiveSec=${ON_UNIT_ACTIVE_SEC}
Persistent=true
Unit=quant-runtime-health.service

[Install]
WantedBy=timers.target
EOF

cat > "${LOGROTATE_FILE}" <<EOF
${LOG_DIR}/*.log {
    daily
    rotate 14
    compress
    delaycompress
    missingok
    notifempty
    copytruncate
    create 0640 root root
}
EOF

systemctl daemon-reload
systemctl enable --now quant-runtime-health.timer
systemctl is-active quant-runtime-health.timer >/dev/null

# 安装阶段只要求 timer 生效；即时全链路校验由 deploy_server.sh 直接执行，
# 这里不主动拉起一次 service，避免服务刚重启时的瞬时 502/404 把安装过程误判为失败。
systemctl reset-failed quant-runtime-health.service >/dev/null 2>&1 || true
systemctl status quant-runtime-health.timer --no-pager -n 20 || true
