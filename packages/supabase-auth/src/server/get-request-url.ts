import "server-only"
import { headers } from "next/headers"

import { LOG_REQUEST_URL_HEADER } from "@workspace/supabase-auth/shared/request-headers"

async function getRequestUrl(): Promise<string | null> {
  const headerStore = await headers()

  return headerStore.get(LOG_REQUEST_URL_HEADER)
}

export { getRequestUrl }
