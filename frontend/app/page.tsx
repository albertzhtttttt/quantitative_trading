import Link from 'next/link'

const appName = process.env.NEXT_PUBLIC_APP_NAME ?? 'Quantitative Trading Console'

const highlights = [
  { label: '后端基线', value: 'FastAPI + SQLAlchemy 2' },
  { label: '前端基线', value: 'Next.js + Tailwind CSS' },
  { label: '部署模式', value: 'Docker Compose + Caddy' },
  { label: '交易阶段', value: '回测优先，模拟盘随后' },
]

export default function HomePage() {
  return (
    <main className="min-h-screen bg-ink text-white">
      <div className="mx-auto flex min-h-screen max-w-7xl flex-col px-6 py-10 lg:px-10">
        <header className="flex items-center justify-between border-b border-white/10 pb-6">
          <div>
            <p className="font-mono text-xs uppercase tracking-[0.32em] text-accent/90">quant console</p>
            <h1 className="mt-3 text-3xl font-semibold tracking-tight lg:text-5xl">{appName}</h1>
          </div>
          <Link
            href="/login"
            className="rounded-full border border-accent/50 px-5 py-2 text-sm font-medium text-accent transition hover:border-accent hover:bg-accent/10"
          >
            进入登录页
          </Link>
        </header>

        <section className="relative mt-10 overflow-hidden rounded-[32px] border border-white/10 bg-[radial-gradient(circle_at_top_left,_rgba(78,205,196,0.16),_transparent_35%),linear-gradient(135deg,_rgba(255,255,255,0.06),_rgba(255,255,255,0.02))] px-6 py-10 shadow-glow lg:px-10">
          <div className="absolute inset-0 bg-trading-grid bg-[size:28px_28px] opacity-20" />
          <div className="relative grid gap-10 lg:grid-cols-[1.4fr_0.8fr]">
            <div>
              <span className="inline-flex rounded-full border border-gold/40 bg-gold/10 px-3 py-1 font-mono text-xs uppercase tracking-[0.28em] text-gold">
                phase 1 baseline
              </span>
              <h2 className="mt-6 max-w-3xl text-2xl font-semibold leading-tight lg:text-4xl">
                先把工程底座打稳，再打通回测、模拟盘与云端部署闭环。
              </h2>
              <p className="mt-5 max-w-2xl text-sm leading-7 text-slate-300 lg:text-base">
                当前版本聚焦工程骨架、容器编排、健康检查和控制台外壳，确保下一步可以直接进入认证、数据模型与回测链路开发。
              </p>
            </div>
            <div className="rounded-[28px] border border-white/10 bg-panel/85 p-6 backdrop-blur">
              <p className="font-mono text-xs uppercase tracking-[0.28em] text-slate-400">delivery baseline</p>
              <ul className="mt-5 space-y-4 text-sm text-slate-200">
                <li>统一环境变量与服务命名</li>
                <li>后端 live / ready 健康检查</li>
                <li>前端首页与登录路由占位</li>
                <li>Compose 编排 frontend / backend / worker / postgres / redis / caddy</li>
              </ul>
            </div>
          </div>
        </section>

        <section className="mt-10 grid gap-4 md:grid-cols-2 xl:grid-cols-4">
          {highlights.map((item) => (
            <article key={item.label} className="rounded-[24px] border border-white/10 bg-white/5 p-5 backdrop-blur-sm">
              <p className="font-mono text-xs uppercase tracking-[0.24em] text-slate-400">{item.label}</p>
              <p className="mt-3 text-lg font-medium text-white">{item.value}</p>
            </article>
          ))}
        </section>
      </div>
    </main>
  )
}
