import type { NextRequest } from "next/server"

import { authConfirmGet } from "../../_lib/handlers/auth-confirm-get"

export async function GET(request: NextRequest) {
  return authConfirmGet(request)
}
