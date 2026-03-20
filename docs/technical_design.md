# 量化交易系统 MVP 技术设计文档

## 1. 文档目标

本文档在 `docs/requirements.md` 的基础上，进一步明确系统的技术实现方案、模块边界、数据模型、接口设计、部署拓扑与实施阶段，用于指导后续正式开发。

本技术设计对应的产品范围为：

- 加密货币市场
- 首期优先完成回测与模拟盘
- 单策略框架
- 单交易所优先，默认以 Binance Spot 为第一接入目标
- 单机 Docker Compose 部署
- 后续可扩展到实盘交易

## 2. 设计原则与关键决策

### 2.1 设计原则

1. 先闭环，再扩展
   - 第一版优先完成“数据 -> 策略 -> 风控 -> 下单/成交 -> 持仓/资产 -> 前端可视化 -> 部署”的完整闭环。

2. 统一执行模型
   - 回测、模拟盘、未来实盘尽量复用相同的策略接口、风控接口与订单模型，只替换执行适配层。

3. 策略与交易所解耦
   - 策略层只关心市场数据、持仓和信号，不直接依赖 Binance SDK 或其他交易所实现。

4. 单体拆模块，不做微服务
   - MVP 采用“前端 + API 服务 + Worker + PostgreSQL + Redis + 反向代理”的单机架构，保持足够清晰，同时避免过早复杂化。

5. 以 K 线驱动为主
   - 第一版采用 Bar-driven 模型，以已收盘 K 线为策略触发基础，不做 Tick 级或高频交易架构。

6. 数据与事件分离
   - 核心业务状态持久化到 PostgreSQL；Redis 只承担缓存、Pub/Sub、控制消息与轻量任务协调，不作为唯一事实来源。

### 2.2 关键技术决策

- 后端语言：Python 3.12
- API 框架：FastAPI
- ORM 与数据模型：SQLAlchemy 2 + Pydantic v2
- 数据库：PostgreSQL 16
- 缓存与消息：Redis 7
- 交易所接入：历史/交易 REST 优先通过 `ccxt` 统一封装；实时行情通过交易所 WebSocket 适配器接入
- 前端框架：Next.js
- 前端状态与数据：TanStack Query + Zustand
- 图表：ECharts 或 Lightweight Charts
- 样式：Tailwind CSS
- 反向代理：Caddy
- 容器编排：Docker Compose

## 3. 总体架构

### 3.1 架构概览

```text
                    +----------------------+
                    |      Web Browser     |
                    +----------+-----------+
                               |
                               v
                    +----------------------+
                    |        Caddy         |
                    |  HTTPS / Reverse     |
                    |       Proxy          |
                    +-----+-----------+----+
                          |           |
                /         |           |         \
               v          v           v          v
      +---------------+  +-------------------+  +----------------+
      |   Frontend    |  |   Backend API     |  |   WebSocket    |
      |   Next.js     |  |   FastAPI         |  |   Gateway      |
      +-------+-------+  +---------+---------+  +--------+-------+
              |                    |                     |
              |                    |                     |
              |              +-----+------+              |
              |              | PostgreSQL |              |
              |              +------------+              |
              |                    ^                     |
              |                    |                     |
              |              +-----+------+              |
              +------------->|   Redis    |<-------------+
                             +-----+------+
                                   ^
                                   |
                             +-----+------+
                             |   Worker    |
                             | Strategy /  |
                             | Backtest /  |
                             | Paper Trade |
                             +-----+------+
                                   |
                      +------------+-------------+
                      | Exchange REST / WebSocket|
                      +--------------------------+
```

### 3.2 服务划分

首期建议拆分为以下 Docker 服务：

1. `frontend`
   - Next.js 前端控制台
   - 提供页面渲染、登录态承接、图表展示、前端交互

2. `backend`
   - FastAPI API 服务
   - 提供认证、策略管理、回测任务创建、订单查询、日志查询、健康检查、WebSocket 接入等能力

3. `worker`
   - 负责长任务和持续运行逻辑
   - 包括回测执行、模拟盘策略运行、行情消费、风控执行、订单状态流转、推送事件发布

4. `postgres`
   - 核心业务数据持久化

5. `redis`
   - Pub/Sub、缓存、轻量状态协作、前后端实时更新辅助

6. `caddy`
   - 对外提供统一域名入口
   - 路由 `/` 到前端，`/api` 与 `/ws` 到后端
   - 生产环境默认承担 HTTPS

## 4. 核心模块设计

## 4.1 后端模块边界

建议后端采用分层模块结构，而不是把全部逻辑堆在路由层。

### 4.1.1 API 层

职责：

- 接收前端请求
- 请求参数校验
- 调用应用服务
- 返回结构化响应
- 暴露 WebSocket 连接入口

建议模块：

- `api/auth`
- `api/dashboard`
- `api/strategies`
- `api/backtests`
- `api/paper_trading`
- `api/orders`
- `api/positions`
- `api/logs`
- `api/health`
- `api/ws`

### 4.1.2 应用服务层

职责：

- 组织业务流程
- 协调仓储、引擎、外部适配器
- 处理状态变更与事件发布

建议服务：

- `AuthService`
- `StrategyService`
- `BacktestService`
- `PaperTradingService`
- `PortfolioService`
- `OrderService`
- `DashboardService`
- `LogService`

### 4.1.3 领域核心层

职责：

- 表达交易系统核心业务能力
- 保持与框架、数据库、交易所 SDK 尽量解耦

建议核心对象：

- `Strategy`
- `Signal`
- `OrderIntent`
- `RiskDecision`
- `PositionState`
- `AccountState`
- `ExecutionMode`
- `BacktestResult`

### 4.1.4 基础设施层

职责：

- 数据库访问
- Redis 通信
- 交易所接入
- 外部配置与日志

建议模块：

- `repositories/*`
- `adapters/exchanges/*`
- `adapters/market_data/*`
- `adapters/pubsub/*`
- `core/config.py`
- `core/logging.py`

## 4.2 Worker 模块设计

Worker 是本系统的核心执行引擎，主要承担 API 不适合直接执行的任务。

### 4.2.1 回测执行器

职责：

- 消费回测任务
- 加载历史 K 线
- 调用策略引擎逐 Bar 执行
- 调用风控和撮合模型
- 计算绩效指标
- 持久化结果并推送完成事件

### 4.2.2 模拟盘运行器

职责：

- 加载已启动的策略配置
- 订阅交易所实时或准实时 K 线
- 在每根 K 线收盘后运行策略
- 在下单前执行风控
- 调用模拟撮合器生成订单/成交/持仓变化
- 更新账户快照并推送前端

### 4.2.3 运行管理器

职责：

- 启停策略运行实例
- 维护每个运行实例的内存态缓存
- 在服务重启后根据数据库状态恢复可恢复任务
- 处理异常退出与重试策略

## 4.3 策略框架设计

### 4.3.1 核心接口约定

首期统一采用 K 线驱动模型。

建议策略抽象如下：

```python
class Strategy:
    key: str
    name: str

    def on_start(self, ctx) -> None:
        ...

    def on_bar(self, ctx, bar, window) -> list[OrderIntent]:
        ...

    def on_stop(self, ctx) -> None:
        ...
```

其中：

- `ctx`：运行上下文，包含账户、持仓、参数、风险配置、日志接口等
- `bar`：当前已收盘 K 线
- `window`：最近一段历史 K 线窗口，供指标计算使用
- `OrderIntent`：策略输出的下单意图，不直接代表最终订单

### 4.3.2 首期策略范围

建议内置两个示例策略：

1. `moving_average_cross`
   - 双均线金叉死叉
   - 用于打通最基础的趋势型策略闭环

2. `breakout` 或 `mean_reversion`
   - 用于验证第二种不同风格的策略结构

### 4.3.3 策略参数设计

每个策略应通过 JSON Schema 风格的参数定义实现前后端联动：

- 参数名称
- 参数类型
- 默认值
- 最小值/最大值
- 描述

这样前端可以自动生成策略参数表单，后端也可执行参数校验。

## 4.4 执行模式统一设计

为保证回测、模拟盘和未来实盘可复用，建议定义统一执行模式：

- `backtest`
- `paper`
- `live`（首期预留，不启用）

统一复用的模块：

- 策略接口
- 风控引擎
- 订单模型
- 持仓与账户模型
- 日志事件模型

按模式替换的模块：

- 市场数据提供器
- 经纪/执行适配器
- 撮合与成交实现

### 4.4.1 Backtest Broker

职责：

- 以历史 K 线驱动成交模拟
- 默认采用“下一根 K 线开盘价 + 手续费 + 滑点”模型
- 输出可复现的回测结果

### 4.4.2 Paper Broker

职责：

- 基于实时行情或最近价格执行模拟撮合
- 维护模拟账户资产、持仓、订单与成交
- 逻辑上尽量贴近未来实盘的订单流转

### 4.4.3 Live Broker

职责：

- 首期仅保留接口，不接真实下单
- 后续通过交易所私有 API 接入真实账户与下单能力

## 4.5 风控引擎设计

风控应位于策略输出与订单执行之间，作为强制拦截层。

### 4.5.1 输入

- 当前账户状态
- 当前持仓状态
- 策略配置
- 风控配置
- 待下单意图
- 最近损益与运行状态

### 4.5.2 输出

- `allow`
- `reject`
- `pause_strategy`

### 4.5.3 首期规则

- 单笔下单金额上限
- 单策略最大仓位限制
- 最大连续亏损限制
- 单日最大亏损限制
- 止损阈值
- 止盈阈值
- 异常重复下单拦截
- 市场数据异常/延迟熔断

### 4.5.4 风控执行链路

```text
Strategy -> OrderIntent -> RiskEngine -> Broker -> Order/Fill -> Position/Account Update
```

每次风控命中时：

- 记录 `event_logs`
- 生成 `alerts`
- 推送到前端日志/告警页
- 必要时将策略运行状态改为 `paused_by_risk`

## 4.6 行情与数据接入设计

### 4.6.1 历史数据

首期历史数据以 K 线为主，来源为交易所公共 REST 接口。

建议流程：

1. 用户发起回测或手动同步历史数据
2. 后端检查本地 `market_candles` 是否已有数据
3. 若数据不足，则调用 Exchange Adapter 补拉并持久化
4. 回测引擎从本地数据库读取历史数据执行

设计目标：

- 历史数据尽量先落库，再使用
- 避免每次回测都直接请求外部接口
- 为后续分析与复盘提供稳定数据源

### 4.6.2 实时数据

模拟盘使用交易所 WebSocket 获取实时或准实时 K 线。

建议策略：

- 首期只消费闭合 K 线事件
- 不直接以逐笔成交驱动策略
- 若 WebSocket 中断，Worker 自动进入重连与告警流程

## 5. 核心业务流程

## 5.1 回测流程

```text
Frontend 提交回测参数
  -> Backend 创建 backtest_runs 记录（pending）
  -> Backend 发布 backtest.requested 事件
  -> Worker 消费任务并更新状态为 running
  -> 加载/补齐历史 K 线
  -> 逐 Bar 调用 Strategy.on_bar
  -> 风控校验
  -> Backtest Broker 模拟成交
  -> 生成交易记录、资金曲线、指标
  -> 写入结果表
  -> 状态更新为 completed/failed
  -> 发布 backtest.completed 事件
  -> Frontend 拉取详情或收到推送刷新页面
```

## 5.2 模拟盘启动流程

```text
Frontend 启动策略
  -> Backend 校验配置并创建 strategy_runs
  -> Backend 发布 strategy.start 事件
  -> Worker 加载策略配置与运行上下文
  -> 订阅对应 symbol/interval 的 K 线流
  -> 接收到闭合 K 线后运行策略
  -> 风控通过后调用 Paper Broker
  -> 更新订单、成交、持仓、账户快照
  -> 发布运行状态和日志事件
  -> Frontend 通过 WebSocket 实时刷新
```

## 5.3 系统重启恢复流程

```text
Worker 启动
  -> 查询 strategy_runs 中状态为 starting/running 的记录
  -> 根据配置尝试恢复模拟盘实例
  -> 若恢复失败，记录错误并置为 error
  -> 生成告警供前端查看
```

## 6. 数据模型设计

## 6.1 数据存储原则

- PostgreSQL 保存所有核心业务事实数据
- Redis 只保存临时缓存、事件流和短期控制消息
- 面向 UI 的可查询日志采用业务事件表，不将所有 stdout 日志写入数据库

## 6.2 核心表设计

### 6.2.1 `users`

用途：管理员登录。

关键字段：

- `id`
- `username`
- `password_hash`
- `is_active`
- `created_at`
- `last_login_at`

### 6.2.2 `strategy_definitions`

用途：定义系统内置或可注册的策略元信息。

关键字段：

- `id`
- `key`
- `name`
- `description`
- `parameter_schema` JSONB
- `default_params` JSONB
- `created_at`

### 6.2.3 `strategy_configs`

用途：保存用户可运行的策略配置实例。

关键字段：

- `id`
- `name`
- `strategy_key`
- `exchange`
- `symbol`
- `interval`
- `mode`（paper/live）
- `params` JSONB
- `risk_params` JSONB
- `status`
- `created_at`
- `updated_at`

### 6.2.4 `strategy_runs`

用途：保存每次策略启动后的运行记录。

关键字段：

- `id`
- `strategy_config_id`
- `mode`
- `status`（starting/running/stopped/error/paused_by_risk）
- `started_at`
- `stopped_at`
- `last_heartbeat_at`
- `last_bar_time`
- `last_error`
- `metrics_snapshot` JSONB

说明：

- 数据结构允许历史多次运行
- 业务规则上，MVP 可限制同一时间只允许 1 个活跃运行实例

### 6.2.5 `market_candles`

用途：保存历史 K 线数据。

关键字段：

- `id`
- `exchange`
- `symbol`
- `interval`
- `open_time`
- `close_time`
- `open`
- `high`
- `low`
- `close`
- `volume`
- `source`
- `created_at`

索引建议：

- 唯一索引：`(exchange, symbol, interval, open_time)`
- 查询索引：`(symbol, interval, open_time)`

### 6.2.6 `backtest_runs`

用途：记录回测任务与结果摘要。

关键字段：

- `id`
- `strategy_key`
- `exchange`
- `symbol`
- `interval`
- `params` JSONB
- `initial_capital`
- `fee_rate`
- `slippage_bps`
- `start_time`
- `end_time`
- `status`
- `summary_metrics` JSONB
- `error_message`
- `created_at`
- `completed_at`

### 6.2.7 `backtest_trades`

用途：保存回测交易明细。

关键字段：

- `id`
- `backtest_run_id`
- `sequence`
- `symbol`
- `side`
- `entry_time`
- `entry_price`
- `exit_time`
- `exit_price`
- `quantity`
- `pnl`
- `pnl_ratio`
- `fee_total`

### 6.2.8 `backtest_equity_points`

用途：保存资金曲线与回撤序列。

关键字段：

- `id`
- `backtest_run_id`
- `ts`
- `equity`
- `drawdown`

### 6.2.9 `orders`

用途：统一保存模拟盘与未来实盘订单。

关键字段：

- `id`
- `run_id`
- `mode`
- `exchange`
- `symbol`
- `side`
- `order_type`
- `quantity`
- `price`
- `status`（new/submitted/partially_filled/filled/canceled/rejected）
- `exchange_order_id`
- `client_order_id`
- `submitted_at`
- `updated_at`
- `rejection_reason`
- `metadata` JSONB

### 6.2.10 `fills`

用途：保存订单成交记录。

关键字段：

- `id`
- `order_id`
- `fill_price`
- `fill_quantity`
- `fee`
- `fee_asset`
- `filled_at`

### 6.2.11 `positions`

用途：保存当前或历史持仓状态。

关键字段：

- `id`
- `run_id`
- `symbol`
- `position_side`
- `quantity`
- `avg_price`
- `market_price`
- `market_value`
- `unrealized_pnl`
- `realized_pnl`
- `updated_at`

### 6.2.12 `account_snapshots`

用途：保存资金曲线、账户权益快照。

关键字段：

- `id`
- `run_id`
- `mode`
- `cash_balance`
- `equity`
- `available_balance`
- `unrealized_pnl`
- `realized_pnl`
- `snapshot_time`

### 6.2.13 `event_logs`

用途：保存前端可查询的业务事件日志。

关键字段：

- `id`
- `level`
- `category`（system/strategy/risk/order/backtest/auth）
- `source`
- `entity_type`
- `entity_id`
- `message`
- `payload` JSONB
- `created_at`

### 6.2.14 `alerts`

用途：保存告警与异常事件。

关键字段：

- `id`
- `severity`
- `type`
- `status`（open/acknowledged/resolved）
- `source`
- `message`
- `payload` JSONB
- `created_at`
- `acknowledged_at`

## 7. API 与实时通信设计

## 7.1 API 设计原则

- REST 为主
- WebSocket 用于实时状态推送
- 所有接口统一版本前缀，例如 `/api/v1`
- 返回统一响应结构，便于前端处理错误和提示

## 7.2 主要 API 列表

### 7.2.1 认证

- `POST /api/v1/auth/login`
- `POST /api/v1/auth/logout`
- `GET /api/v1/auth/me`

### 7.2.2 仪表盘

- `GET /api/v1/dashboard/overview`
- `GET /api/v1/dashboard/performance`
- `GET /api/v1/dashboard/recent-events`

### 7.2.3 策略管理

- `GET /api/v1/strategies/definitions`
- `GET /api/v1/strategies/configs`
- `POST /api/v1/strategies/configs`
- `PUT /api/v1/strategies/configs/{id}`
- `POST /api/v1/strategies/configs/{id}/start`
- `POST /api/v1/strategies/configs/{id}/stop`
- `GET /api/v1/strategies/runs`
- `GET /api/v1/strategies/runs/{id}`

### 7.2.4 回测

- `POST /api/v1/backtests`
- `GET /api/v1/backtests`
- `GET /api/v1/backtests/{id}`
- `GET /api/v1/backtests/{id}/equity`
- `GET /api/v1/backtests/{id}/trades`

### 7.2.5 模拟盘与交易数据

- `GET /api/v1/paper/account`
- `GET /api/v1/paper/positions`
- `GET /api/v1/orders`
- `GET /api/v1/orders/{id}`
- `GET /api/v1/fills`

### 7.2.6 日志与告警

- `GET /api/v1/logs`
- `GET /api/v1/alerts`
- `POST /api/v1/alerts/{id}/ack`

### 7.2.7 健康检查

- `GET /api/v1/health/live`
- `GET /api/v1/health/ready`

## 7.3 WebSocket 推送设计

建议统一使用一个 WebSocket 连接，并通过 topic 区分消息类型。

### 7.3.1 Topic 建议

- `dashboard.overview`
- `strategy.run.updated`
- `order.updated`
- `position.updated`
- `account.updated`
- `backtest.updated`
- `log.created`
- `alert.created`

### 7.3.2 推送来源

- Worker 在关键状态变化时向 Redis Pub/Sub 发布事件
- Backend WebSocket 层订阅 Redis 并转发给前端连接

这样可以避免前端直接依赖 Worker，也便于未来增加多实例扩展。

## 8. 前端技术设计

## 8.1 技术选型

建议前端采用：

- `Next.js`：负责路由、页面结构、部署一致性
- `TypeScript`：保证接口类型和交互安全性
- `Tailwind CSS`：提升界面实现效率
- `TanStack Query`：负责服务端数据查询与缓存
- `Zustand`：管理少量实时状态和界面状态
- `ECharts` 或 `Lightweight Charts`：显示资金曲线、K 线、收益图
- `Framer Motion`：用于少量有意义的过渡动画

## 8.2 信息架构

建议页面结构如下：

1. `Overview`
   - 总资产卡片
   - 模拟收益
   - 活跃策略状态
   - 最近订单与告警
   - 资金曲线摘要

2. `Strategies`
   - 策略定义列表
   - 配置实例列表
   - 参数编辑抽屉或表单
   - 启动/停止操作

3. `Backtests`
   - 参数配置面板
   - 回测任务列表
   - 结果详情页
   - 指标卡片、收益曲线、交易表格

4. `Paper Trading`
   - 当前账户资产
   - 当前持仓
   - 当前订单与最新成交
   - 实时日志流

5. `Orders & Fills`
   - 历史订单筛选
   - 成交记录筛选

6. `Logs & Alerts`
   - 业务日志
   - 风控日志
   - 告警列表

## 8.3 前端视觉方向

前端建议采用“专业交易控制台”风格，而不是普通 CRUD 后台模板。

建议视觉基线：

- 主色调：深石墨灰、冷蓝灰作为背景基础
- 功能强调色：盈利用绿色、亏损用红色、关键状态用金色或青色
- 字体：`IBM Plex Sans` 作为主字体，`JetBrains Mono` 用于数字和价格信息
- 布局：左侧导航 + 顶部全局状态栏 + 主区域多卡片仪表盘
- 动效：页面首次载入的分段出现、图表和告警区的轻量过渡

要求：

- 桌面端体验优先
- 移动端至少支持查看关键摘要与运行状态
- 数据密集型页面保持可读性，不追求花哨动画

## 8.4 前后端交互方式

- 列表与详情：REST API
- 实时状态：WebSocket
- 前端通过统一 API Client 处理鉴权与错误
- 优先使用服务端定义的类型生成或共享 schema，减少字段漂移

## 9. Docker 与部署拓扑设计

## 9.1 推荐 Compose 服务

```text
services:
  caddy
  frontend
  backend
  worker
  postgres
  redis
```

## 9.2 网络与路由

- 对外只暴露 `caddy`
- `frontend`、`backend`、`worker`、`postgres`、`redis` 只在内部网络通信
- Caddy 路由：
  - `/` -> `frontend:3000`
  - `/api/*` -> `backend:8000`
  - `/ws/*` -> `backend:8000`

## 9.3 持久化卷

建议持久化内容：

- `postgres_data`
- 应用上传/导出目录（如果后续有）
- Caddy 证书目录

说明：

- Redis 不作为唯一状态存储，即使 Redis 数据丢失，也不应导致历史业务数据丢失

## 9.4 环境变量设计

首期至少包含：

- `APP_ENV`
- `SECRET_KEY`
- `DATABASE_URL`
- `REDIS_URL`
- `ADMIN_USERNAME`
- `ADMIN_PASSWORD`
- `DEFAULT_EXCHANGE`
- `BINANCE_API_KEY`（未来实盘预留）
- `BINANCE_API_SECRET`（未来实盘预留）
- `ENABLE_LIVE_TRADING=false`

关键约束：

- `ENABLE_LIVE_TRADING` 默认为 `false`
- 第一版即使保留实盘接口，也必须通过显式环境变量开关才允许启用真实交易路径

## 10. 安全、审计与可观测性设计

## 10.1 认证与会话

建议方案：

- 后端负责登录认证
- 登录成功后签发 HttpOnly Cookie 或短期 JWT + Refresh Token
- 单管理员模型即可，不做多角色权限体系

在单域名反向代理下，推荐使用 HttpOnly Cookie，避免把访问令牌暴露在浏览器脚本环境中。

## 10.2 密钥与敏感配置

- 所有敏感信息只通过环境变量或服务器安全配置注入
- 禁止写入 Git 仓库
- 数据库只保存脱敏信息或未来的密钥引用信息，不直接以明文落库

## 10.3 审计与日志

分为两类：

1. 基础服务日志
   - 输出到 stdout/stderr
   - 通过 `docker logs` 查看

2. 业务事件日志
   - 保存到 `event_logs`
   - 在前端可筛选和检索
   - 用于查看策略运行、风控拦截、回测状态、订单变化

## 10.4 健康检查

建议提供：

- API 存活检查
- 数据库连通性检查
- Redis 连通性检查
- Worker 心跳检查

## 10.5 告警机制

首期只做站内告警：

- 风控触发
- Worker 异常
- WebSocket 断流重连失败
- 交易所接口异常
- 回测失败

后续可再接入 Telegram 或邮件。

## 11. 测试与质量保障

## 11.1 后端测试

至少包含：

- 策略单元测试
- 风控规则单元测试
- 回测引擎单元测试
- API 集成测试
- Repository 层数据库测试

## 11.2 前端测试

至少包含：

- 关键页面渲染测试
- 核心表单交互测试
- 回测页与策略页的关键流程测试

## 11.3 端到端验证

至少包含：

1. 登录后台
2. 创建策略配置
3. 发起回测
4. 查看回测结果与收益曲线
5. 启动模拟盘
6. 查看订单、持仓、资产、日志变化
7. 重启服务后验证数据仍可查询

## 12. 默认目录结构建议

建议项目采用如下目录结构：

```text
quantitative_trading/
├─ backend/
│  ├─ app/
│  │  ├─ api/
│  │  ├─ core/
│  │  ├─ domain/
│  │  ├─ services/
│  │  ├─ repositories/
│  │  ├─ adapters/
│  │  ├─ schemas/
│  │  └─ main.py
│  ├─ worker/
│  │  ├─ runners/
│  │  ├─ jobs/
│  │  └─ main.py
│  ├─ migrations/
│  ├─ tests/
│  ├─ Dockerfile
│  └─ requirements.txt 或 pyproject.toml
├─ frontend/
│  ├─ app/ 或 src/
│  ├─ components/
│  ├─ features/
│  ├─ lib/
│  ├─ styles/
│  ├─ public/
│  ├─ Dockerfile
│  └─ package.json
├─ infra/
│  ├─ caddy/
│  └─ scripts/
├─ docs/
│  ├─ requirements.md
│  ├─ technical_design.md
│  └─ deployment.md
├─ docker-compose.yml
├─ .env.example
└─ README.md
```

## 13. 分阶段实施建议

## 13.1 Phase 1：项目骨架与基础设施

目标：

- 初始化前后端项目
- 搭建 Docker Compose
- 打通 PostgreSQL、Redis、Caddy
- 实现基础登录、健康检查、项目首页框架

## 13.2 Phase 2：数据层与回测闭环

目标：

- 建立数据库模型与迁移
- 完成 K 线历史数据同步
- 实现策略框架与第一个示例策略
- 完成回测引擎与回测结果展示

## 13.3 Phase 3：模拟盘闭环

目标：

- 实现 Worker 策略运行器
- 接入实时 K 线
- 实现 Paper Broker
- 完成订单、持仓、账户、日志实时更新

## 13.4 Phase 4：风控、观测与部署完善

目标：

- 完成风控链路
- 完成日志与告警页
- 补全部署文档与运行文档
- 完成容器部署验证

## 13.5 Phase 5：实盘预留能力梳理

目标：

- 梳理 Live Broker 接口
- 增加密钥管理与安全约束
- 对接真实交易前的开关、审计与确认机制

## 14. 当前推荐结论

本项目推荐采用以下落地方案：

- 架构形态：单机单体拆模块，`frontend + backend + worker + postgres + redis + caddy`
- 策略模型：统一 K 线驱动策略接口
- 首期交易模式：回测 + 模拟盘
- 首期执行器：Backtest Broker + Paper Broker
- 扩展路线：后续新增 Live Broker 而不重写策略和风控核心
- 部署方案：Docker Compose 部署到单台 Ubuntu 云服务器

该方案的优点是：

- 开发路径清晰
- MVP 范围可控
- 技术复杂度适中
- 能较好支撑后续扩展到实盘和多交易所
