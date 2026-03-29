import { getSafeRedirectTo } from "@workspace/supabase-auth/shared/auth-redirect"

type AuthSearchParamValue = string | string[] | undefined
type AuthSearchParams = Promise<Record<string, AuthSearchParamValue>>

function getSearchParamValue(value: AuthSearchParamValue) {
  if (Array.isArray(value)) {
    return value[0]
  }

  return value
}

async function resolveAuthSearchParams(searchParams: AuthSearchParams) {
  const resolved = await searchParams

  return {
    auth: getSearchParamValue(resolved.auth),
    redirectTo: getSafeRedirectTo(getSearchParamValue(resolved.redirect_to)),
    required: getSearchParamValue(resolved.required),
  }
}

export { resolveAuthSearchParams, type AuthSearchParams }
