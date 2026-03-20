import type { Metadata } from 'next'
import '@/styles/globals.css'

const appName = process.env.NEXT_PUBLIC_APP_NAME ?? '量化交易控制台'

export const metadata: Metadata = {
  title: appName,
  description: '面向加密货币量化交易 MVP 的控制台。',
}

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="zh-CN">
      <body>{children}</body>
    </html>
  )
}
