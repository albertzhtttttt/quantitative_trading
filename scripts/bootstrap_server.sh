#!/usr/bin/env bash
set -euo pipefail

# 该脚本用于在一台全新 Ubuntu 24.04 服务器上初始化量化交易项目运行环境。
# 默认安装 Nginx、Node.js、Redis、PostgreSQL、Python venv 依赖，并写入 systemd 与 Nginx 配置模板。

APP_ROOT="${APP_ROOT:-/opt/quantitative_trading}"
APP_USER="${APP_USER:-root}"
PUBLIC_HOST="${PUBLIC_HOST:-47.119.136.200}"
APP_NAME="${APP_NAME:-量化交易控制台}"
ADMIN_USERNAME="${ADMIN_USERNAME:-admin}"
ADMIN_PASSWORD="${ADMIN_PASSWORD:-change-me-before-production}"
SECRET_KEY="${SECRET_KEY:-change-me-before-production}"
POSTGRES_DB="${POSTGRES_DB:-quantitative_trading}"
POSTGRES_USER="${POSTGRES_USER:-quant}"
POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-change-me-before-production}"
SESSION_COOKIE_NAME="${SESSION_COOKIE_NAME:-qt_session}"
SESSION_MAX_AGE="${SESSION_MAX_AGE:-86400}"
SESSION_COOKIE_SECURE="${SESSION_COOKIE_SECURE:-false}"

# 统一安装项目运行所需依赖；Docker 保留安装，便于后续恢复 compose 方案或做本地镜像实验。
apt-get update
apt-get install -y ca-certificates curl gnupg lsb-release git nginx nodejs npm redis-server python3-venv build-essential postgresql postgresql-contrib

systemctl enable --now redis-server
systemctl enable --now postgresql

# 初始化 PostgreSQL 应用用户与数据库；重复执行时会自动跳过已存在对象。
sudo -u postgres psql -tAc "SELECT 1 FROM pg_roles WHERE rolname='${POSTGRES_USER}'" | grep -q 1 || \
  sudo -u postgres psql -c "CREATE ROLE ${POSTGRES_USER} WITH LOGIN PASSWORD '${POSTGRES_PASSWORD}';"
sudo -u postgres psql -tAc "SELECT 1 FROM pg_database WHERE datname='${POSTGRES_DB}'" | grep -q 1 || \
  sudo -u postgres psql -c "CREATE DATABASE ${POSTGRES_DB} OWNER ${POSTGRES_USER};"
sudo -u postgres psql -c "ALTER ROLE ${POSTGRES_USER} WITH LOGIN PASSWORD '${POSTGRES_PASSWORD}';"

mkdir -p "${APP_ROOT}/backend" "${APP_ROOT}/frontend" "${APP_ROOT}/infra" "${APP_ROOT}/docs" "${APP_ROOT}/scripts" "${APP_ROOT}/backups/postgres"

# 预写后端环境变量模板，后续 deploy_server.sh 会直接复用，不需要再次交互输入。
cat > "${APP_ROOT}/backend/.env" <<EOF
APP_ENV=production
SECRET_KEY=${SECRET_KEY}
ADMIN_USERNAME=${ADMIN_USERNAME}
ADMIN_PASSWORD=${ADMIN_PASSWORD}
DEFAULT_EXCHANGE=binance
ENABLE_LIVE_TRADING=false
SESSION_COOKIE_NAME=${SESSION_COOKIE_NAME}
SESSION_MAX_AGE=${SESSION_MAX_AGE}
SESSION_COOKIE_SECURE=${SESSION_COOKIE_SECURE}
CORS_ALLOW_ORIGINS=http://${PUBLIC_HOST},https://${PUBLIC_HOST}
DATABASE_URL=postgresql+psycopg://${POSTGRES_USER}:${POSTGRES_PASSWORD}@127.0.0.1:5432/${POSTGRES_DB}
REDIS_URL=redis://127.0.0.1:6379/0
EOF

mkdir -p /etc/nginx/ssl
if [ ! -f /etc/nginx/ssl/quantitative_trading.key ]; then
  openssl req -x509 -nodes -newkey rsa:2048 -days 365 \
    -keyout /etc/nginx/ssl/quantitative_trading.key \
    -out /etc/nginx/ssl/quantitative_trading.crt \
    -subj "/CN=${PUBLIC_HOST}" \
    -addext "subjectAltName = IP:${PUBLIC_HOST}"
fi
chmod 600 /etc/nginx/ssl/quantitative_trading.key
chmod 644 /etc/nginx/ssl/quantitative_trading.crt

# Nginx 统一作为公网入口，80 做跳转，443 代理前端页面与后端 API。
cat > /etc/nginx/sites-available/quantitative_trading <<'EOF'
server {
    listen 80;
    server_name _;
    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl http2;
    server_name _;

    ssl_certificate /etc/nginx/ssl/quantitative_trading.crt;
    ssl_certificate_key /etc/nginx/ssl/quantitative_trading.key;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;

    location /api/ {
        proxy_pass http://127.0.0.1:8000;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    location / {
        proxy_pass http://127.0.0.1:3000;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
EOF
ln -sf /etc/nginx/sites-available/quantitative_trading /etc/nginx/sites-enabled/quantitative_trading
rm -f /etc/nginx/sites-enabled/default
nginx -t
systemctl enable --now nginx
systemctl restart nginx

# 预写 systemd 模板；应用代码与虚拟环境到位后，deploy_server.sh 会直接重启这些服务。
cat > /etc/systemd/system/quant-backend.service <<EOF
[Unit]
Description=Quantitative Trading Backend
After=network.target redis-server.service postgresql.service
Wants=redis-server.service postgresql.service

[Service]
Type=simple
WorkingDirectory=${APP_ROOT}/backend
Environment=PYTHONPATH=${APP_ROOT}/backend
ExecStart=${APP_ROOT}/backend/.venv/bin/uvicorn app.main:app --host 127.0.0.1 --port 8000
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

cat > /etc/systemd/system/quant-frontend.service <<EOF
[Unit]
Description=Quantitative Trading Frontend
After=network.target quant-backend.service
Wants=quant-backend.service

[Service]
Type=simple
WorkingDirectory=${APP_ROOT}/frontend
Environment=NODE_ENV=production
Environment=HOSTNAME=127.0.0.1
Environment=PORT=3000
ExecStart=/usr/bin/node ${APP_ROOT}/frontend/.next/standalone/server.js
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

cat > /etc/systemd/system/quant-worker.service <<EOF
[Unit]
Description=Quantitative Trading Worker
After=network.target redis-server.service postgresql.service
Wants=redis-server.service postgresql.service

[Service]
Type=simple
WorkingDirectory=${APP_ROOT}/backend
Environment=PYTHONPATH=${APP_ROOT}/backend
ExecStart=${APP_ROOT}/backend/.venv/bin/python -m worker.main
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload

echo "Bootstrap completed for ${PUBLIC_HOST}."
echo "Next step: upload code, then run scripts/deploy_server.sh"
