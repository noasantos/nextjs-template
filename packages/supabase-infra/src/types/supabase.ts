import type { SupabaseClient } from "@supabase/supabase-js"

import type { Database } from "@workspace/supabase-infra/types/database"

export type TypedSupabaseClient = SupabaseClient<Database>
