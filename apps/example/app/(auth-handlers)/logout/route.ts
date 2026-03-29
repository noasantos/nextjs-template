import type { NextRequest } from "next/server"

import { logoutGet } from "../_lib/handlers/logout-get"

export async function GET(request: NextRequest) {
  return logoutGet(request)
}
