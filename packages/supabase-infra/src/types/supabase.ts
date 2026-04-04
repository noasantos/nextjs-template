/**
 * Typed Supabase client type
 *
 * This type is used throughout the codebase to ensure type safety
 */
import type { SupabaseClient } from "@supabase/supabase-js"

import type { Database } from "@workspace/supabase-infra/types/database.types"

export type TypedSupabaseClient = SupabaseClient<Database>
