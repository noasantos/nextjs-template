"use client"

import * as React from "react"

import {
  BadgeCheck,
  Bell,
  ChevronsUpDown,
  CreditCard,
  LogOut,
  Settings,
  Sparkles,
} from "lucide-react"

import {
  Avatar,
  AvatarFallback,
  AvatarImage,
} from "@workspace/ui/components/avatar"
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuGroup,
  DropdownMenuItem,
  DropdownMenuLabel,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from "@workspace/ui/components/dropdown-menu"
import {
  SidebarMenu,
  SidebarMenuButton,
  SidebarMenuItem,
  useSidebar,
} from "@workspace/ui/components/sidebar"

export function NavUser({
  user,
  settingsHref,
  SettingsLink,
}: {
  user: {
    name: string
    email: string
    avatar: string
  }
  /** When set, hides Upgrade/Billing and shows Definições (e.g. admin app). */
  settingsHref?: string
  /** Optional client router link (e.g. Next `Link`) for Definições. Falls back to `<a>`. */
  SettingsLink?: React.ComponentType<{
    href: string
    className?: string
    children: React.ReactNode
  }>
}) {
  const { isMobile } = useSidebar()

  return (
    <SidebarMenu>
      <SidebarMenuItem>
        <DropdownMenu>
          <DropdownMenuTrigger asChild>
            <SidebarMenuButton
              size="lg"
              className="data-[state=open]:bg-sidebar-accent data-[state=open]:text-sidebar-accent-foreground"
            >
              <Avatar className="h-8 w-8 rounded-lg">
                <AvatarImage src={user.avatar} alt={user.name} />
                <AvatarFallback className="rounded-lg">CN</AvatarFallback>
              </Avatar>
              <div className="grid flex-1 text-left text-sm leading-tight">
                <span className="truncate font-medium">{user.name}</span>
                <span className="truncate text-xs">{user.email}</span>
              </div>
              <ChevronsUpDown strokeWidth={2} className="ml-auto size-4" />
            </SidebarMenuButton>
          </DropdownMenuTrigger>
          <DropdownMenuContent
            className="w-(--radix-dropdown-menu-trigger-width) min-w-56 rounded-lg"
            side={isMobile ? "bottom" : "right"}
            align="end"
            sideOffset={4}
          >
            <DropdownMenuLabel className="p-0 font-normal">
              <div className="flex items-center gap-2 px-1 py-1.5 text-left text-sm">
                <Avatar className="h-8 w-8 rounded-lg">
                  <AvatarImage src={user.avatar} alt={user.name} />
                  <AvatarFallback className="rounded-lg">CN</AvatarFallback>
                </Avatar>
                <div className="grid flex-1 text-left text-sm leading-tight">
                  <span className="truncate font-medium">{user.name}</span>
                  <span className="truncate text-xs">{user.email}</span>
                </div>
              </div>
            </DropdownMenuLabel>
            <DropdownMenuSeparator />
            {settingsHref ? (
              <>
                <DropdownMenuGroup>
                  <DropdownMenuItem asChild>
                    {SettingsLink ? (
                      <SettingsLink href={settingsHref}>
                        <Settings strokeWidth={2} />
                        Definições
                      </SettingsLink>
                    ) : (
                      <a href={settingsHref}>
                        <Settings strokeWidth={2} />
                        Definições
                      </a>
                    )}
                  </DropdownMenuItem>
                  <DropdownMenuItem>
                    <BadgeCheck strokeWidth={2} />
                    Conta
                  </DropdownMenuItem>
                  <DropdownMenuItem>
                    <Bell strokeWidth={2} />
                    Notificações
                  </DropdownMenuItem>
                </DropdownMenuGroup>
                <DropdownMenuSeparator />
                <DropdownMenuItem>
                  <LogOut strokeWidth={2} />
                  Sair
                </DropdownMenuItem>
              </>
            ) : (
              <>
                <DropdownMenuGroup>
                  <DropdownMenuItem>
                    <Sparkles strokeWidth={2} />
                    Upgrade to Pro
                  </DropdownMenuItem>
                </DropdownMenuGroup>
                <DropdownMenuSeparator />
                <DropdownMenuGroup>
                  <DropdownMenuItem>
                    <BadgeCheck strokeWidth={2} />
                    Account
                  </DropdownMenuItem>
                  <DropdownMenuItem>
                    <CreditCard strokeWidth={2} />
                    Billing
                  </DropdownMenuItem>
                  <DropdownMenuItem>
                    <Bell strokeWidth={2} />
                    Notifications
                  </DropdownMenuItem>
                </DropdownMenuGroup>
                <DropdownMenuSeparator />
                <DropdownMenuItem>
                  <LogOut strokeWidth={2} />
                  Log out
                </DropdownMenuItem>
              </>
            )}
          </DropdownMenuContent>
        </DropdownMenu>
      </SidebarMenuItem>
    </SidebarMenu>
  )
}
