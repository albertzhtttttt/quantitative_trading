#!/usr/bin/env bash
set -euo pipefail

# 统一定位仓库根目录，确保脚本从任意子目录执行时都能拿到正确的源码快照。
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# 默认对接当前线上服务器；如后续更换机器或目录，可通过环境变量覆盖。
DEPLOY_HOST="${DEPLOY_HOST:-47.119.136.200}"
DEPLOY_USER="${DEPLOY_USER:-root}"
DEPLOY_PATH="${DEPLOY_PATH:-/opt/quantitative_trading}"
RUN_SERVER_TESTS="${RUN_SERVER_TESTS:-1}"

REMOTE="${DEPLOY_USER}@${DEPLOY_HOST}"
SSH_OPTS=("-o" "StrictHostKeyChecking=no")

# 只上传当前 HEAD 的受版本控制文件，避免把本地 node_modules、虚拟环境和临时文件带上服务器。
git -C "${REPO_ROOT}" archive --format=tar HEAD | ssh "${SSH_OPTS[@]}" "${REMOTE}" "mkdir -p '${DEPLOY_PATH}' && tar -xf - -C '${DEPLOY_PATH}' && mkdir -p '${DEPLOY_PATH}/backups/postgres'"

# 服务器端复用已存在的 .env、systemd 和 Nginx 配置，只负责更新代码、依赖、构建产物与服务进程。
ssh "${SSH_OPTS[@]}" "${REMOTE}" bash <<EOF
set -euo pipefail

cd "${DEPLOY_PATH}"

if [ ! -f backend/.env ]; then
  echo "缺少 backend/.env，请先完成服务器初始化。" >&2
  exit 1
fi

cd backend
if [ ! -d .venv ]; then
  python3 -m venv .venv
fi
. .venv/bin/activate
pip install --upgrade pip
pip install .

# 后端回归优先在服务器本机执行，确保线上运行依赖和基础认证链路没有被新版本破坏。
if [ "${RUN_SERVER_TESTS}" = "1" ]; then
  pytest tests/test_auth.py tests/test_health.py
fi

cd ../frontend
npm ci
NEXT_PUBLIC_API_BASE_URL=/api/v1 npm run build

# standalone server 运行时需要同时看到 public 和 .next/static；这里显式建立链接，避免静态资源 404。
mkdir -p .next/standalone/.next
rm -rf .next/standalone/.next/static .next/standalone/public
ln -s "$(pwd)/.next/static" .next/standalone/.next/static
ln -s "$(pwd)/public" .next/standalone/public

# 统一重启对外入口和三类应用进程，确保前端、后端与 worker 都使用最新代码。
systemctl restart quant-backend.service
systemctl restart quant-frontend.service
systemctl restart quant-worker.service
systemctl restart nginx

systemctl is-active quant-backend.service >/dev/null
systemctl is-active quant-frontend.service >/dev/null
systemctl is-active quant-worker.service >/dev/null
systemctl is-active nginx >/dev/null
curl --fail --silent http://127.0.0.1/api/v1/health/live >/dev/null

echo "Deploy completed: http://${DEPLOY_HOST}"
EOF
