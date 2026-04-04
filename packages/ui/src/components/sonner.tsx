"use client"

import { AlertTriangle, CircleCheck, CircleX, Info, Loader2 } from "lucide-react"
import { useTheme } from "next-themes"
import * as React from "react"
import { Toaster as Sonner, type ToasterProps } from "sonner"

const Toaster = ({ ...props }: ToasterProps) => {
  const { theme = "system" } = useTheme()

  const sonnerCssVariables = {
    "--normal-bg": "var(--popover)",
    "--normal-text": "var(--popover-foreground)",
    "--normal-border": "var(--border)",
    "--border-radius": "var(--radius)",
  }

  return (
    <Sonner
      theme={(theme as ToasterProps["theme"]) || "system"}
      className="toaster group"
      icons={{
        success: <CircleCheck strokeWidth={2} className="size-4" />,
        info: <Info strokeWidth={2} className="size-4" />,
        warning: <AlertTriangle strokeWidth={2} className="size-4" />,
        error: <CircleX strokeWidth={2} className="size-4" />,
        loading: <Loader2 strokeWidth={2} className="size-4 animate-spin" />,
      }}
      style={sonnerCssVariables as React.CSSProperties}
      toastOptions={{
        classNames: {
          toast: "cn-toast",
        },
      }}
      {...props}
    />
  )
}

export { Toaster }
