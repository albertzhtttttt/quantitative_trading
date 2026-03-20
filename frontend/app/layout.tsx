import type { Metadata } from 'next'
import '@/styles/globals.css'

const appName = process.env.NEXT_PUBLIC_APP_NAME ?? 'Quantitative Trading Console'

export const metadata: Metadata = {
  title: appName,
  description: 'Crypto quantitative trading MVP control console.',
}

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="zh-CN">
      <body>{children}</body>
    </html>
  )
}
