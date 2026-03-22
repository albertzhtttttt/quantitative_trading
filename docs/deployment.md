# 服务器部署与运维说明

## 当前线上结构

当前线上入口统一由 `nginx` 提供：

- `http://47.119.136.200`：自动跳转到 HTTPS
- `https://47.119.136.200`：前端首页
- `https://47.119.136.200/api/v1/*`：后端 API

应用进程全部只监听本机回环地址：

- `quant-frontend.service` -> `127.0.0.1:3000`
- `quant-backend.service` -> `127.0.0.1:8000`
- `quant-worker.service` -> 后台任务占位进程
- `postgresql` -> `127.0.0.1:5432`
- `redis-server` -> `127.0.0.1:6379`

## 目录约定

- 项目目录：`/opt/quantitative_trading`
- 后端环境文件：`/opt/quantitative_trading/backend/.env`
- Nginx 站点配置：`/etc/nginx/sites-available/quantitative_trading`
- TLS 证书：`/etc/nginx/ssl/quantitative_trading.crt`
- TLS 私钥：`/etc/nginx/ssl/quantitative_trading.key`

## systemd 服务

查看状态：

```bash
systemctl status quant-backend.service
systemctl status quant-frontend.service
systemctl status quant-worker.service
systemctl status nginx
```

重启服务：

```bash
systemctl restart quant-backend.service
systemctl restart quant-frontend.service
systemctl restart quant-worker.service
systemctl restart nginx
```

查看日志：

```bash
journalctl -u quant-backend.service -n 100 --no-pager
journalctl -u quant-frontend.service -n 100 --no-pager
journalctl -u quant-worker.service -n 100 --no-pager
journalctl -u nginx -n 100 --no-pager
```

## 部署方式

日常更新优先使用仓库内脚本：

```bash
bash scripts/deploy_server.sh
```

脚本行为：

1. 上传当前 `HEAD` 代码到服务器
2. 安装 / 更新后端依赖
3. 运行后端认证与健康检查测试
4. 安装前端依赖并重新构建
5. 修复 standalone 运行时静态资源链接
6. 重启 backend / frontend / worker / nginx
7. 安装 / 刷新运行时健康检查 timer 与日志轮转配置
8. 立即执行一次全链路健康检查

可用环境变量：

- `DEPLOY_HOST`
- `DEPLOY_USER`
- `DEPLOY_PATH`
- `RUN_SERVER_TESTS`

示例：

```bash
DEPLOY_HOST=47.119.136.200 DEPLOY_USER=root bash scripts/deploy_server.sh
```

## 初始化新服务器

对于全新 Ubuntu 24.04 服务器，可先执行：

```bash
bash scripts/bootstrap_server.sh
```

该脚本会完成：

- 安装 Nginx / Node.js / Redis / PostgreSQL / Python venv 依赖
- 初始化 PostgreSQL 用户与数据库
- 生成自签名 TLS 证书
- 写入 Nginx 配置
- 写入 systemd 服务模板
- 预创建 `/var/log/quantitative_trading`
- 预写日志轮转配置
- 预写后端 `.env`

## 数据库与管理员账号

当前默认数据库：

- 数据库名：`quantitative_trading`
- 用户名：`quant`

当前管理员用户名默认使用：

- `admin`

管理员密码来源于 `backend/.env` 中的：

- `ADMIN_PASSWORD`

修改管理员密码后，重启后端即可自动同步到数据库：

```bash
systemctl restart quant-backend.service
```

## 健康检查与联调

后端健康检查：

```bash
curl -k https://127.0.0.1/api/v1/health/live
curl -k https://47.119.136.200/api/v1/health/live
```

前端首页：

```bash
curl -k -I https://47.119.136.200
```

## 数据备份与恢复

PostgreSQL 备份脚本：

```bash
bash scripts/backup_postgres.sh
```

恢复脚本：

```bash
bash scripts/restore_postgres.sh <backup-file>
```

服务器定时备份安装脚本：

```bash
bash scripts/install_backup_timer.sh
```

默认行为：

- 备份目录：`/opt/quantitative_trading/backups/postgres`
- 保留天数：`7`
- 默认定时：每天 `03:45`

查看备份 timer：

```bash
systemctl status quant-postgres-backup.service
systemctl status quant-postgres-backup.timer
systemctl list-timers --all | grep quant-postgres-backup
```

恢复演练建议优先恢复到临时校验库，避免覆盖线上库：

```bash
TARGET_DATABASE=quantitative_trading_restore_check bash scripts/restore_postgres.sh /opt/quantitative_trading/backups/postgres/postgres-YYYYMMDD-HHMMSS.sql
```

如确需直接覆盖线上库，必须显式确认并设置：

```bash
ALLOW_PRODUCTION_RESTORE=1 bash scripts/restore_postgres.sh /opt/quantitative_trading/backups/postgres/postgres-YYYYMMDD-HHMMSS.sql
```

## 运行时健康检查与日志轮转

安装运行时健康检查 timer：

```bash
bash scripts/install_runtime_health_timer.sh
```

默认行为：

- 健康检查入口：`https://127.0.0.1/api/v1/health/ready`
- 前端探测地址：`https://127.0.0.1/login`
- 执行频率：开机后 `2` 分钟启动，之后每 `5` 分钟执行一次
- 日志文件：`/var/log/quantitative_trading/runtime-health.log`
- 日志轮转：`/etc/logrotate.d/quantitative_trading`，按天切分，保留 `14` 份压缩日志

查看健康检查 timer：

```bash
systemctl status quant-runtime-health.service
systemctl status quant-runtime-health.timer
systemctl list-timers --all | grep quant-runtime-health
journalctl -u quant-runtime-health.service -n 50 --no-pager
```

手动执行健康检查：

```bash
bash scripts/check_runtime_health.sh
```

## TLS 说明

当前 HTTPS 使用自签名证书，浏览器会提示证书不受信任，但加密链路有效。

后续如果绑定正式域名，可进一步切换为受信任证书（例如 Let's Encrypt）。
