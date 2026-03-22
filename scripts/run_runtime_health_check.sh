#!/usr/bin/env bash
set -euo pipefail

# 作为 systemd 健康检查 service 的统一入口，
# 成功时把原始输出继续交给 systemd 写入常规运行日志；
# 失败时额外把时间戳、退出码和原始错误输出落到独立告警日志，
# 这样即使没有外部通知渠道，也能快速看到最近一次异常细节。
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHECK_SCRIPT="${CHECK_SCRIPT:-${SCRIPT_DIR}/check_runtime_health.sh}"
LOG_DIR="${LOG_DIR:-/var/log/quantitative_trading}"
ALERT_LOG="${ALERT_LOG:-${LOG_DIR}/runtime-health-alert.log}"
OUTPUT_FILE="$(mktemp)"

cleanup() {
  rm -f "${OUTPUT_FILE}"
}
trap cleanup EXIT

mkdir -p "${LOG_DIR}"

if "${CHECK_SCRIPT}" >"${OUTPUT_FILE}" 2>&1; then
  cat "${OUTPUT_FILE}"
  exit 0
fi

STATUS="$?"
TIMESTAMP="$(date '+%Y-%m-%dT%H:%M:%S%z')"

{
  printf '[%s] runtime health check failed (exit=%s)\n' "${TIMESTAMP}" "${STATUS}"
  cat "${OUTPUT_FILE}"
  printf '\n'
} >>"${ALERT_LOG}"

cat "${OUTPUT_FILE}" >&2
exit "${STATUS}"
