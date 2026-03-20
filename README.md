# Quantitative Trading

一个面向加密货币市场的量化交易 MVP，优先完成回测闭环，再扩展到模拟盘，采用 FastAPI 后端、Next.js 前端和 Docker Compose 部署。

## 文档

- `docs/requirements.md`
- `docs/technical_design.md`
- `docs/TODO.md`

## 当前阶段

当前仓库已经完成 Phase 1 的工程基线：

- FastAPI 后端骨架与健康检查
- Next.js 控制台首页与登录页占位
- `frontend`、`backend`、`worker`、`postgres`、`redis`、`caddy` 的 Compose 编排
- `.env.example` 环境变量模板

## 快速启动

1. 复制 `.env.example` 为 `.env`
2. 运行 `docker compose up -d --build`
3. 打开 `http://localhost`
4. 检查 `http://localhost/api/v1/health/live`

## 说明

- 默认通过 `ENABLE_LIVE_TRADING=false` 禁用实盘路径
- 真实密钥只放在 `.env`，不得提交到仓库
- 除 `README.md` 外，其余项目文档统一放在 `docs/`
- 如果 Docker Desktop 未启动，容器联调会失败，但本地代码测试仍可执行
