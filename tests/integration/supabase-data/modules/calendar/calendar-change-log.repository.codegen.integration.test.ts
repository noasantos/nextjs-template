// codegen:backend — do not hand-edit; regenerate with `pnpm codegen:backend --write`.

import { describe, it } from "vitest"

import { CalendarChangeLogSupabaseRepository } from "@workspace/supabase-data/modules/calendar/infrastructure/repositories/calendar-change-log-supabase.repository.codegen"

describe.skip("calendar-change-log repository (codegen scaffold)", () => {
  it("CRUD round-trip — wire Supabase test client and un-skip", () => {
    void CalendarChangeLogSupabaseRepository
  })
})
