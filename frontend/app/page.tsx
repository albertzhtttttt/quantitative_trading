'use client'

import Link from 'next/link'
import { useCallback, useEffect, useState } from 'react'
import { AppShell } from '@/components/app-shell'
import { ApiError, apiGet, apiPost } from '@/lib/api/client'
import { appConfig } from '@/lib/config'

// 与后端 CurrentUserResponse 对齐，首页只依赖这些字段判断会话状态和展示当前管理员信息。
type CurrentUser = {
  id: number
  username: string
  is_active: boolean
  last_login_at: string | null
}

// 登出接口当前只返回提示文案，前端随后会重新拉取 /auth/me 校验会话状态。
type LogoutResponse = {
  message: string
}

// 首页统一维护会话状态、提示文案和当前用户，避免在渲染阶段散落多组布尔值。
type SessionState = {
  status: 'loading' | 'guest' | 'authenticated'
  message: string
  user: CurrentUser | null
}

const highlights = [
  { label: '认证链路', value: 'HttpOnly Cookie Session' },
  { label: '前端交互', value: 'Next.js App Router' },
  { label: '部署模式', value: 'Docker Compose + Caddy' },
  { label: '当前阶段', value: 'T06 最小演示闭环' },
]

// 把后端返回的最后登录时间转换为适合控制台展示的本地时间；没有时间时保留明确占位。
function formatLastLogin(lastLoginAt: string | null): string {
  if (!lastLoginAt) {
    return '本次为首次登录'
  }

  const parsedDate = new Date(lastLoginAt)
  if (Number.isNaN(parsedDate.getTime())) {
    return lastLoginAt
  }

  return new Intl.DateTimeFormat('zh-CN', {
    dateStyle: 'medium',
    timeStyle: 'short',
  }).format(parsedDate)
}

// 首页在浏览器加载后主动调用 /auth/me，依据 HttpOnly Cookie 判断当前是否仍处于已登录状态。
export default function HomePage() {
  const [sessionState, setSessionState] = useState<SessionState>({
    status: 'loading',
    message: '正在校验当前浏览器中的登录会话。',
    user: null,
  })
  const [isLoggingOut, setIsLoggingOut] = useState(false)

  // 每次进入首页或主动刷新时都重新读取后端会话，确保页面状态完全以后端为准。
  const loadSession = useCallback(async () => {
    setSessionState({
      status: 'loading',
      message: '正在校验当前浏览器中的登录会话。',
      user: null,
    })

    try {
      const user = await apiGet<CurrentUser>('/auth/me')
      setSessionState({
        status: 'authenticated',
        message: '当前浏览器已通过 HttpOnly Cookie 恢复管理员会话。',
        user,
      })
    } catch (error) {
      if (error instanceof ApiError && error.status === 401) {
        setSessionState({
          status: 'guest',
          message: '当前浏览器未持有有效会话，请先登录。',
          user: null,
        })
        return
      }

      setSessionState({
        status: 'guest',
        message: error instanceof Error ? error.message : '获取当前会话失败，请稍后重试。',
        user: null,
      })
    }
  }, [])

  useEffect(() => {
    void loadSession()
  }, [loadSession])

  // 登出只调用后端接口清理 Cookie，再重新读取当前会话，不在前端手动操作 Cookie。
  async function handleLogout() {
    if (isLoggingOut) {
      return
    }

    setIsLoggingOut(true)

    try {
      await apiPost<LogoutResponse>('/auth/logout')
      await loadSession()
    } catch (error) {
      const message = error instanceof Error ? error.message : '退出登录失败，请稍后重试。'

      setSessionState((current) => ({
        status: current.user ? 'authenticated' : 'guest',
        message,
        user: current.user,
      }))
    } finally {
      setIsLoggingOut(false)
    }
  }

  const isAuthenticated = sessionState.status === 'authenticated' && sessionState.user !== null
  const currentUser = isAuthenticated ? sessionState.user : null

  return (
    <main className="min-h-screen bg-ink text-white">
      <div className="mx-auto flex min-h-screen max-w-7xl flex-col px-6 py-10 lg:px-10">
        <header className="flex flex-col gap-4 border-b border-white/10 pb-6 lg:flex-row lg:items-center lg:justify-between">
          <div>
            <p className="font-mono text-xs uppercase tracking-[0.32em] text-accent/90">量化控制台</p>
            <h1 className="mt-3 text-3xl font-semibold tracking-tight lg:text-5xl">{appConfig.appName}</h1>
          </div>
          <div className="inline-flex w-fit rounded-full border border-white/10 bg-white/5 px-4 py-2 text-sm text-slate-200">
            {isAuthenticated ? '管理员已登录' : '等待管理员登录'}
          </div>
        </header>

        <section className="relative mt-10 overflow-hidden rounded-[32px] border border-white/10 bg-[radial-gradient(circle_at_top_left,_rgba(78,205,196,0.16),_transparent_35%),linear-gradient(135deg,_rgba(255,255,255,0.06),_rgba(255,255,255,0.02))] px-6 py-10 shadow-glow lg:px-10">
          <div className="absolute inset-0 bg-trading-grid bg-[size:28px_28px] opacity-20" />
          <div className="relative grid gap-10 lg:grid-cols-[1.35fr_0.85fr]">
            <div>
              <span className="inline-flex rounded-full border border-gold/40 bg-gold/10 px-3 py-1 font-mono text-xs uppercase tracking-[0.28em] text-gold">
                T06 最小认证闭环
              </span>
              <h2 className="mt-6 max-w-3xl text-2xl font-semibold leading-tight lg:text-4xl">
                管理员登录、会话恢复与退出链路已经接入浏览器控制台。
              </h2>
              <p className="mt-5 max-w-2xl text-sm leading-7 text-slate-300 lg:text-base">
                当前页面会在加载后自动访问 `/auth/me` 判断当前浏览器是否仍持有有效会话；退出操作只调用后端接口，
                由浏览器与 HttpOnly Cookie 自然完成状态切换。
              </p>
              <div className="mt-8 grid gap-4 md:grid-cols-2">
                <article className="rounded-[24px] border border-white/10 bg-white/5 p-5 backdrop-blur-sm">
                  <p className="font-mono text-xs uppercase tracking-[0.24em] text-slate-400">接口范围</p>
                  <p className="mt-3 text-sm leading-7 text-slate-200">
                    `/auth/login`、`/auth/me`、`/auth/logout` 三条接口已经覆盖最小演示链路。
                  </p>
                </article>
                <article className="rounded-[24px] border border-white/10 bg-white/5 p-5 backdrop-blur-sm">
                  <p className="font-mono text-xs uppercase tracking-[0.24em] text-slate-400">状态来源</p>
                  <p className="mt-3 text-sm leading-7 text-slate-200">
                    页面不直接读写 Cookie，所有登录状态都以后端会话接口返回结果为准。
                  </p>
                </article>
              </div>
            </div>

            <AppShell
              eyebrow="会话状态"
              title={
                currentUser
                  ? `已登录：${currentUser.username}`
                  : sessionState.status === 'loading'
                    ? '正在检查登录状态'
                    : '当前未登录'
              }
              subtitle={sessionState.message}
            >
              {sessionState.status === 'loading' ? (
                <div className="space-y-3">
                  <div className="h-20 animate-pulse rounded-2xl border border-white/10 bg-white/5" />
                  <div className="h-12 animate-pulse rounded-2xl border border-white/10 bg-white/5" />
                </div>
              ) : null}

              {sessionState.status === 'guest' ? (
                <div className="space-y-4">
                  <div className="rounded-2xl border border-white/10 bg-white/5 p-4 text-sm leading-7 text-slate-300">
                    登录成功后刷新页面时，首页会自动通过 `/auth/me` 恢复当前管理员身份；如果还未登录，直接前往登录页即可。
                  </div>
                  <div className="flex flex-col gap-3 sm:flex-row">
                    <Link
                      href="/login"
                      className="inline-flex items-center justify-center rounded-2xl bg-accent px-4 py-3 text-sm font-semibold text-ink transition hover:bg-[#5fe0d7]"
                    >
                      前往登录
                    </Link>
                    <button
                      type="button"
                      onClick={() => void loadSession()}
                      className="inline-flex items-center justify-center rounded-2xl border border-white/10 bg-white/5 px-4 py-3 text-sm font-medium text-slate-200 transition hover:border-accent/50 hover:text-white"
                    >
                      重新检查会话
                    </button>
                  </div>
                </div>
              ) : null}

              {currentUser ? (
                <div className="space-y-4">
                  <div className="grid gap-4 sm:grid-cols-2">
                    <article className="rounded-2xl border border-white/10 bg-white/5 p-4">
                      <p className="font-mono text-xs uppercase tracking-[0.24em] text-slate-400">当前用户</p>
                      <p className="mt-3 text-lg font-medium text-white">{currentUser.username}</p>
                    </article>
                    <article className="rounded-2xl border border-white/10 bg-white/5 p-4">
                      <p className="font-mono text-xs uppercase tracking-[0.24em] text-slate-400">最后登录</p>
                      <p className="mt-3 text-sm leading-7 text-slate-200">{formatLastLogin(currentUser.last_login_at)}</p>
                    </article>
                  </div>
                  <div className="rounded-2xl border border-white/10 bg-white/5 p-4 text-sm leading-7 text-slate-300">
                    当前状态由浏览器自动携带的 HttpOnly Cookie 驱动；点击退出登录后，页面会重新请求 `/auth/me` 验证会话是否已清理。
                  </div>
                  <div className="flex flex-col gap-3 sm:flex-row">
                    <button
                      type="button"
                      onClick={handleLogout}
                      disabled={isLoggingOut}
                      className="inline-flex items-center justify-center rounded-2xl bg-accent px-4 py-3 text-sm font-semibold text-ink transition hover:bg-[#5fe0d7] disabled:cursor-not-allowed disabled:bg-accent/60"
                    >
                      {isLoggingOut ? '正在退出...' : '退出登录'}
                    </button>
                    <button
                      type="button"
                      onClick={() => void loadSession()}
                      className="inline-flex items-center justify-center rounded-2xl border border-white/10 bg-white/5 px-4 py-3 text-sm font-medium text-slate-200 transition hover:border-accent/50 hover:text-white"
                    >
                      刷新会话
                    </button>
                  </div>
                </div>
              ) : null}
            </AppShell>
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
