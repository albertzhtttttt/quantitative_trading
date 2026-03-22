#!/usr/bin/env bash
set -euo pipefail

# 通过本机 Nginx HTTPS 入口同时校验后端 ready 接口和前端页面，
# 这样既能覆盖应用进程状态，也能覆盖反向代理与 TLS 入口是否正常工作。
PUBLIC_BASE_URL="${PUBLIC_BASE_URL:-https://127.0.0.1}"
BACKEND_READY_URL="${BACKEND_READY_URL:-${PUBLIC_BASE_URL}/api/v1/health/ready}"
FRONTEND_URL="${FRONTEND_URL:-${PUBLIC_BASE_URL}/login}"
CURL_OPTS=("--fail" "--silent" "--show-error" "--insecure")

# 先获取 ready 响应正文，再用 Python 做结构化校验，避免仅凭 HTTP 200 掩盖依赖退化。
READY_PAYLOAD="$(curl "${CURL_OPTS[@]}" "${BACKEND_READY_URL}")"
python3 - <<'PY' "${READY_PAYLOAD}"
import json
import sys

payload = json.loads(sys.argv[1])
if payload.get("status") != "ok":
    raise SystemExit(f"后端 ready 状态异常: {payload}")

for dependency in payload.get("dependencies", []):
    if not dependency.get("ok", False):
        raise SystemExit(f"后端依赖检查失败: {payload}")
PY

# 再校验前端登录页 HTML 与至少一个 `/_next/static` 资源，
# 避免出现页面能返回文本但样式 / JS 资源 404 的假健康状态。
FRONTEND_HTML="$(curl "${CURL_OPTS[@]}" "${FRONTEND_URL}")"
STATIC_ASSET_PATH="$(python3 - <<'PY' "${FRONTEND_HTML}"
import re
import sys

html = sys.argv[1]
match = re.search(r'(["\'])((?:/_next/static/)[^"\']+)(["\'])', html)
if not match:
    raise SystemExit("未在前端页面中找到 /_next/static 资源引用")
print(match.group(2))
PY
)"
STATIC_ASSET_HEADERS="$(curl -I "${CURL_OPTS[@]}" "${PUBLIC_BASE_URL}${STATIC_ASSET_PATH}")"
python3 - <<'PY' "${STATIC_ASSET_PATH}" "${STATIC_ASSET_HEADERS}"
import sys

asset_path, headers = sys.argv[1:3]
status_line = headers.splitlines()[0] if headers else ""
if " 200 " not in status_line:
    raise SystemExit(f"静态资源返回异常: {asset_path} -> {status_line or 'unknown'}")
PY

echo "Health check passed: ${FRONTEND_URL} -> ${STATIC_ASSET_PATH}"
