'use client'

import Link from 'next/link'
import { useRouter } from 'next/navigation'
import { type FormEvent, useState } from 'react'
import { AppShell } from '@/components/app-shell'
import { apiPost } from '@/lib/api/client'
import { appConfig } from '@/lib/config'

// 与后端 CurrentUserResponse 对齐，登录成功后前端只关心最小用户信息。
type CurrentUser = {
  id: number
  username: string
  is_active: boolean
  last_login_at: string | null
}

// 登录接口会返回提示文案和当前用户信息，页面只需据此完成跳转。
type LoginResponse = {
  message: string
  user: CurrentUser
}

// 登录页只承接最小认证闭环：提交管理员凭证，成功后让浏览器通过 HttpOnly Cookie 自动保持会话。
export default function LoginPage() {
  const router = useRouter()
  const [username, setUsername] = useState('')
  const [password, setPassword] = useState('')
  const [errorMessage, setErrorMessage] = useState('')
  const [isSubmitting, setIsSubmitting] = useState(false)

  // 统一处理提交状态和错误提示，直接复用后端返回的认证失败文案。
  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()

    if (isSubmitting) {
      return
    }

    setErrorMessage('')
    setIsSubmitting(true)

    try {
      await apiPost<LoginResponse>('/auth/login', { username, password })
      router.replace('/')
    } catch (error) {
      setErrorMessage(error instanceof Error ? error.message : '登录失败，请稍后重试。')
    } finally {
      setIsSubmitting(false)
    }
  }

  return (
    <main className="relative min-h-screen overflow-hidden bg-ink text-white">
      <div className="absolute inset-0 bg-trading-grid bg-[size:28px_28px] opacity-15" />
      <div className="absolute inset-x-0 top-0 h-72 bg-[radial-gradient(circle_at_top,_rgba(78,205,196,0.22),_transparent_55%)]" />
      <div className="relative mx-auto flex min-h-screen max-w-6xl items-center px-6 py-10 lg:px-10">
        <div className="grid w-full gap-8 lg:grid-cols-[0.92fr_1.08fr]">
          <section className="rounded-[32px] border border-white/10 bg-[radial-gradient(circle_at_top_left,_rgba(212,175,55,0.16),_transparent_36%),linear-gradient(135deg,_rgba(255,255,255,0.06),_rgba(255,255,255,0.02))] p-8 shadow-glow backdrop-blur">
            <p className="font-mono text-xs uppercase tracking-[0.32em] text-accent/90">T06 认证闭环</p>
            <h1 className="mt-5 text-3xl font-semibold leading-tight lg:text-5xl">{appConfig.appName}</h1>
            <p className="mt-5 max-w-xl text-sm leading-7 text-slate-300 lg:text-base">
              管理员登录成功后，浏览器会自动携带 HttpOnly Cookie 访问 `/auth/me` 与 `/auth/logout`，
              用最小改动完成登录、会话恢复与退出链路。
            </p>
            <div className="mt-8 grid gap-4">
              <div className="rounded-[24px] border border-white/10 bg-white/5 p-5">
                <p className="font-mono text-xs uppercase tracking-[0.24em] text-slate-400">当前范围</p>
                <ul className="mt-4 space-y-3 text-sm text-slate-200">
                  <li>对接 `POST /api/v1/auth/login` 建立管理员会话</li>
                  <li>通过 `GET /api/v1/auth/me` 恢复浏览器中的登录状态</li>
                  <li>通过 `POST /api/v1/auth/logout` 清理 Cookie 会话</li>
                </ul>
              </div>
              <Link
                href="/"
                className="inline-flex w-fit rounded-full border border-accent/50 px-5 py-2 text-sm font-medium text-accent transition hover:border-accent hover:bg-accent/10 hover:text-white"
              >
                返回首页查看会话面板
              </Link>
            </div>
          </section>

          <AppShell
            eyebrow="管理员入口"
            title="管理员登录"
            subtitle="输入管理员用户名和密码后，登录页只负责发起请求；会话由浏览器中的 HttpOnly Cookie 自动保存。"
          >
            <form className="space-y-5" onSubmit={handleSubmit}>
              <div className="space-y-2">
                <label htmlFor="username" className="text-sm font-medium text-slate-200">
                  用户名
                </label>
                <input
                  id="username"
                  name="username"
                  type="text"
                  autoComplete="username"
                  required
                  value={username}
                  onChange={(event) => setUsername(event.target.value)}
                  placeholder="请输入管理员用户名"
                  className="w-full rounded-2xl border border-white/10 bg-black/20 px-4 py-3 text-sm text-white outline-none transition placeholder:text-slate-500 focus:border-accent/70 focus:bg-black/30"
                />
              </div>

              <div className="space-y-2">
                <label htmlFor="password" className="text-sm font-medium text-slate-200">
                  密码
                </label>
                <input
                  id="password"
                  name="password"
                  type="password"
                  autoComplete="current-password"
                  required
                  value={password}
                  onChange={(event) => setPassword(event.target.value)}
                  placeholder="请输入管理员密码"
                  className="w-full rounded-2xl border border-white/10 bg-black/20 px-4 py-3 text-sm text-white outline-none transition placeholder:text-slate-500 focus:border-accent/70 focus:bg-black/30"
                />
              </div>

              {errorMessage ? (
                <div className="rounded-2xl border border-rose-400/30 bg-rose-500/10 px-4 py-3 text-sm text-rose-100">
                  {errorMessage}
                </div>
              ) : null}

              <button
                type="submit"
                disabled={isSubmitting}
                className="inline-flex w-full items-center justify-center rounded-2xl bg-accent px-4 py-3 text-sm font-semibold text-ink transition hover:bg-[#5fe0d7] disabled:cursor-not-allowed disabled:bg-accent/60"
              >
                {isSubmitting ? '正在登录...' : '登录并进入首页'}
              </button>
            </form>

            <div className="mt-6 rounded-2xl border border-white/10 bg-white/5 p-4 text-sm leading-7 text-slate-300">
              登录成功后无需前端手动存储 token；刷新页面时，首页会直接根据 Cookie 重新读取当前管理员会话。
            </div>
          </AppShell>
        </div>
      </div>
    </main>
  )
}
