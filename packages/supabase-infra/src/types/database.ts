import type { Database as DatabaseGenerated } from "./database.types.js"
import type { TypedSupabaseClient } from "./supabase.js"

type PublicFunctions = DatabaseGenerated["public"]["Functions"]

type MergedPublicFunctions = PublicFunctions

type Database = Omit<DatabaseGenerated, "public"> & {
  public: Omit<DatabaseGenerated["public"], "Functions"> & {
    Functions: MergedPublicFunctions
  }
}

export type { Json } from "./database.types.js"
export type { Database, DatabaseGenerated, TypedSupabaseClient }
