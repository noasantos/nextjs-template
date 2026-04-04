import type { PostgrestError } from "@supabase/supabase-js"
import { expect } from "vitest"

function expectForbidden(error: PostgrestError | null) {
  expect(error).not.toBeNull()
  expect(error?.code ?? error?.message).toBeTruthy()
}

function expectNoRowsVisible<T>(rows: T[] | null) {
  expect(rows ?? []).toEqual([])
}

function expectVisibleIds(
  rows: ReadonlyArray<{ id: string }> | null,
  expectedIds: ReadonlyArray<string>
) {
  expect([...(rows ?? []).map((row) => row.id)].sort()).toEqual([...expectedIds].sort())
}

export { expectForbidden, expectNoRowsVisible, expectVisibleIds }
