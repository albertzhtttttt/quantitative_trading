import Link from 'next/link'

export default function LoginPage() {
  return (
    <main className="flex min-h-screen items-center justify-center bg-ink px-6 py-10 text-white">
      <section className="w-full max-w-md rounded-[28px] border border-white/10 bg-panel/90 p-8 shadow-glow backdrop-blur">
        <p className="font-mono text-xs uppercase tracking-[0.28em] text-accent/90">admin access</p>
        <h1 className="mt-4 text-3xl font-semibold">管理员登录</h1>
        <p className="mt-3 text-sm leading-7 text-slate-300">
          该页面已为 `T06` 预留。下一阶段将接入真实登录接口、会话管理与受保护路由。
        </p>
        <div className="mt-8 rounded-2xl border border-dashed border-white/15 bg-white/5 p-5 text-sm text-slate-300">
          当前基线仅完成控制台外壳与路由占位，不提交真实凭证表单逻辑。
        </div>
        <Link href="/" className="mt-8 inline-flex text-sm font-medium text-accent transition hover:text-white">
          返回首页
        </Link>
      </section>
    </main>
  )
}
