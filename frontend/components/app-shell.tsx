type AppShellProps = {
  title: string
  subtitle: string
  children?: React.ReactNode
}

export function AppShell({ title, subtitle, children }: AppShellProps) {
  return (
    <section className="rounded-[28px] border border-white/10 bg-panel/85 p-6 shadow-glow backdrop-blur">
      <p className="font-mono text-xs uppercase tracking-[0.24em] text-slate-400">control console</p>
      <h2 className="mt-4 text-2xl font-semibold text-white">{title}</h2>
      <p className="mt-3 text-sm leading-7 text-slate-300">{subtitle}</p>
      {children ? <div className="mt-6">{children}</div> : null}
    </section>
  )
}
