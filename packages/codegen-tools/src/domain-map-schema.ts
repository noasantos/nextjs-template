import { z } from "zod"

const kebabCaseId = z
  .string()
  .regex(/^[a-z0-9]+(-[a-z0-9]+)*$/, "Domain id must be kebab-case (e.g. user-roles)")

const DomainEntrySchema = z.object({
  auth: z.enum(["public", "session", "admin"]).optional(),
  codegen: z.boolean().optional().default(true),
  exposeActions: z.boolean().optional().default(true),
  id: kebabCaseId,
  readOnly: z.boolean().optional().default(false),
  tables: z.array(z.string().min(1)).min(1),
})

const DomainMapFileSchema = z.object({
  domains: z.array(DomainEntrySchema),
  ignoreTables: z.array(z.string().min(1)).optional().default([]),
  version: z.literal(1),
})

type DomainMapFile = z.infer<typeof DomainMapFileSchema>
type DomainEntry = z.infer<typeof DomainEntrySchema>

function parseDomainMapJson(raw: unknown): DomainMapFile {
  return DomainMapFileSchema.parse(raw)
}

export {
  DomainEntrySchema,
  DomainMapFileSchema,
  type DomainEntry,
  type DomainMapFile,
  parseDomainMapJson,
}
