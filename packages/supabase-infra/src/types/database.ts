import type { Database as DatabaseGenerated } from "@workspace/supabase-infra/types/database.types"

type PublicFunctions = DatabaseGenerated["public"]["Functions"]

type MergedPublicFunctions = PublicFunctions

type Database = Omit<DatabaseGenerated, "public"> & {
  public: Omit<DatabaseGenerated["public"], "Functions"> & {
    Functions: MergedPublicFunctions
  }
}

export type { Database }
export type { DatabaseGenerated }
