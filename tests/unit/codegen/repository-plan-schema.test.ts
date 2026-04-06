import { describe, expect, it } from "vitest"

import { parseRepositoryPlanJson } from "../../../packages/codegen-tools/src/repository-plan-schema.ts"

describe("parseRepositoryPlanJson", () => {
  it("accepts a minimal valid plan", () => {
    const plan = parseRepositoryPlanJson({
      version: 1,
      meta: { generatedAt: "2026-01-01T00:00:00.000Z", generator: "test" },
      entries: [
        {
          domainId: "victicio",
          table: "demo_widgets",
          read: { kind: "table", name: "demo_widgets" },
          methods: ["findById"],
          dto: { style: "zod", include: "all_columns" },
        },
      ],
    })
    expect(plan.entries).toHaveLength(1)
  })

  it("rejects upsert without onConflict", () => {
    expect(() =>
      parseRepositoryPlanJson({
        version: 1,
        meta: { generatedAt: "2026-01-01T00:00:00.000Z", generator: "test" },
        entries: [
          {
            domainId: "victicio",
            table: "demo_widgets",
            read: { kind: "table", name: "demo_widgets" },
            methods: ["upsert"],
            dto: { style: "zod", include: "all_columns" },
          },
        ],
      })
    ).toThrow()
  })
})
