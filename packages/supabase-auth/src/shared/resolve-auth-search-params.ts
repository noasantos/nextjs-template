import { getSafeRedirectTo } from "./auth-redirect"

type AuthSearchParamValue = string | string[] | undefined

export type AuthSearchParams = Promise<Record<string, AuthSearchParamValue>>

function getSearchParamValue(value: AuthSearchParamValue) {
  if (Array.isArray(value)) {
    return value[0]
  }

  return value
}

export async function resolveAuthSearchParams(searchParams: AuthSearchParams) {
  const resolved = await searchParams

  return {
    auth: getSearchParamValue(resolved.auth),
    redirectTo: getSafeRedirectTo(getSearchParamValue(resolved.redirect_to)),
    required: getSearchParamValue(resolved.required),
  }
}
