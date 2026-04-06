import { z } from "zod"

const ReadWriteTargetSchema = z.object({
  kind: z.enum(["table", "view"]),
  name: z.string().min(1),
})

const RepositoryMethodSchema = z.enum([
  "findById",
  "list",
  "insert",
  "update",
  "upsert",
  "delete",
  "softDelete",
])

const DtoIncludeSchema = z.union([
  z.literal("all_columns"),
  z.object({ columns: z.array(z.string().min(1)).min(1) }),
])

const RepositoryPlanEntrySchema = z
  .object({
    domainId: z.string().min(1),
    table: z.string().min(1),
    read: ReadWriteTargetSchema,
    write: ReadWriteTargetSchema.optional(),
    methods: z.array(RepositoryMethodSchema).min(1),
    idColumn: z.string().min(1).optional(),
    softDelete: z
      .object({
        column: z.string().min(1),
        value: z.unknown().optional(),
      })
      .optional(),
    dto: z.object({
      style: z.enum(["zod", "type"]),
      include: DtoIncludeSchema,
    }),
    list: z
      .object({
        pageSizeDefault: z.number().int().positive().optional(),
        maxPageSize: z.number().int().positive().optional(),
        filterFields: z.array(z.string()).optional(),
        orderBy: z.array(z.string()).optional(),
      })
      .optional(),
    upsert: z
      .object({
        onConflict: z.string().min(1),
      })
      .optional(),
    customMethods: z
      .array(
        z.object({
          name: z.string().min(1),
          notes: z.string().optional(),
        })
      )
      .optional(),
    deferred: z.boolean().optional(),
  })
  .refine((entry) => !entry.methods.includes("upsert") || Boolean(entry.upsert?.onConflict), {
    message: 'methods includes "upsert" but upsert.onConflict is missing',
    path: ["upsert"],
  })
  .refine((entry) => !entry.methods.includes("softDelete") || Boolean(entry.softDelete?.column), {
    message: 'methods includes "softDelete" but softDelete.column is missing',
    path: ["softDelete"],
  })
  .refine(
    (entry) => {
      const writes =
        entry.methods.includes("insert") ||
        entry.methods.includes("update") ||
        entry.methods.includes("upsert") ||
        entry.methods.includes("delete") ||
        entry.methods.includes("softDelete")
      return entry.read.kind !== "view" || !writes || Boolean(entry.write)
    },
    {
      message: "read.kind is view and write methods are present but write target is missing",
      path: ["write"],
    }
  )

const RepositoryPlanMetaSchema = z.object({
  generatedAt: z.string().min(1),
  generator: z.string().min(1),
  model: z.string().optional(),
  promptVersion: z.string().optional(),
})

const RepositoryPlanFileSchema = z.object({
  version: z.literal(1),
  meta: RepositoryPlanMetaSchema,
  entries: z.array(RepositoryPlanEntrySchema),
})

type RepositoryPlanFile = z.infer<typeof RepositoryPlanFileSchema>
type RepositoryPlanEntry = z.infer<typeof RepositoryPlanEntrySchema>
type RepositoryMethod = z.infer<typeof RepositoryMethodSchema>

function parseRepositoryPlanJson(raw: unknown): RepositoryPlanFile {
  return RepositoryPlanFileSchema.parse(raw)
}

export {
  parseRepositoryPlanJson,
  RepositoryMethodSchema,
  RepositoryPlanEntrySchema,
  RepositoryPlanFileSchema,
  type RepositoryMethod,
  type RepositoryPlanEntry,
  type RepositoryPlanFile,
}
