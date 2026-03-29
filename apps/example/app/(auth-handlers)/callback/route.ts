import type { NextRequest } from "next/server"

import { callbackGet } from "../_lib/handlers/callback-get"

export async function GET(request: NextRequest) {
  return callbackGet(request)
}
