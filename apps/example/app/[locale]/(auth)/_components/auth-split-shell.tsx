import { cn } from "@workspace/ui/lib/utils"

import { AuthVisualPanel } from "@/app/[locale]/(auth)/_components/auth-visual-panel"

type AuthSplitShellProps = {
  children: React.ReactNode
  className?: string
  /** When false, only the left column is shown (e.g. small screens still get a single column). */
  showVisualPanel?: boolean
}

function AuthSplitShell({
  children,
  className,
  showVisualPanel = true,
}: AuthSplitShellProps) {
  return (
    <div
      className={cn(
        "w-full max-w-3xl overflow-hidden rounded-2xl border border-border bg-card shadow-none",
        className
      )}
    >
      <div className="grid min-h-[min(32rem,calc(100svh-8rem))] grid-cols-1 md:grid-cols-[minmax(0,1fr)_minmax(16rem,20rem)]">
        <div className="flex min-w-0 flex-col justify-start bg-background px-6 py-10 sm:px-8 sm:py-12 md:justify-center md:rounded-l-2xl md:py-14">
          {children}
        </div>
        {showVisualPanel ? <AuthVisualPanel /> : null}
      </div>
    </div>
  )
}

export { AuthSplitShell }
