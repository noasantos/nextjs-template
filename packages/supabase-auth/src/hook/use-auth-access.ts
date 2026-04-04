"use client"

import * as React from "react"

import { createBrowserAuthClient } from "@workspace/supabase-auth/browser/create-browser-auth-client"
import type { AuthRole } from "@workspace/supabase-auth/shared/auth-role"
import {
  getAccessFromClaims,
  type AccessFromClaims,
} from "@workspace/supabase-auth/shared/get-access-from-claims"
import type { Permission } from "@workspace/supabase-auth/shared/permission"

type AuthAccessState = AccessFromClaims & {
  isLoading: boolean
}

function emptyAccessState(): AuthAccessState {
  return {
    accessVersion: null,
    isLoading: true,
    permissions: [],
    roles: [],
    subscription: {},
  }
}

async function loadAccessState() {
  const supabase = createBrowserAuthClient()
  const { data } = await supabase.auth.getClaims()
  const claims = data?.claims ?? null

  if (!claims?.sub) {
    return {
      ...emptyAccessState(),
      isLoading: false,
    }
  }

  const access = getAccessFromClaims(claims)

  return {
    ...access,
    isLoading: false,
  }
}

function useAuthAccess() {
  const [state, setState] = React.useState<AuthAccessState>(() => emptyAccessState())

  const refresh = React.useCallback(async () => {
    const supabase = createBrowserAuthClient()
    await supabase.auth.refreshSession()
    setState((current: AuthAccessState) => ({
      ...current,
      isLoading: true,
    }))
    setState(await loadAccessState())
  }, [])

  React.useEffect(() => {
    let isActive = true
    const supabase = createBrowserAuthClient()

    void loadAccessState().then((nextState) => {
      if (isActive) {
        setState(nextState)
      }
    })

    const {
      data: { subscription },
    } = supabase.auth.onAuthStateChange(() => {
      void loadAccessState().then((nextState) => {
        if (isActive) {
          setState(nextState)
        }
      })
    })

    return () => {
      isActive = false
      subscription.unsubscribe()
    }
  }, [])

  return {
    accessVersion: state.accessVersion,
    can: (permission: Permission) => state.permissions.includes(permission),
    hasRole: (role: AuthRole) => state.roles.includes(role),
    isLoading: state.isLoading,
    permissions: state.permissions,
    refresh,
    roles: state.roles,
    subscription: state.subscription,
  }
}

export { useAuthAccess }
