/* oxlint-disable eslint-plugin-import/no-relative-parent-imports -- internal package subfolder */
import { existsSync, mkdirSync, writeFileSync } from "node:fs"
import { dirname, join } from "node:path"

import type { DomainMapFile } from "../domain-map-schema"
import { pascalFromSnake } from "./naming"
import { repositoryPath } from "./paths"

type LegacyStubResult = {
  errors: string[]
  filesWritten: string[]
}

function emitLegacyStubForTable(opts: {
  checkOnly: boolean
  domainId: string
  repoRoot: string
  table: string
}): LegacyStubResult {
  const errors: string[] = []
  const filesWritten: string[] = []
  const { checkOnly, domainId, repoRoot, table } = opts
  const path = repositoryPath(repoRoot, domainId, table)
  if (existsSync(path)) {
    return { errors, filesWritten }
  }
  if (checkOnly) {
    errors.push(`Missing generated repository (run without --check --write): ${path}`)
    return { errors, filesWritten }
  }
  const pascal = pascalFromSnake(table)
  const entityKebab = table.replace(/_/g, "-")
  const portRelativeImport = ["..", "..", "domain", "ports", `${entityKebab}-repository.port`].join(
    "/"
  )
  mkdirSync(dirname(path), { recursive: true })
  const body = `import type { SupabaseClient } from "@supabase/supabase-js"

import { SupabaseRepositoryError } from "@workspace/supabase-data/lib/supabase-repository-error"

import type { ${pascal}Repository } from "${portRelativeImport}"

/**
 * Codegen stub for table "${table}" (domain "${domainId}").
 * Replace with real queries and DTO mapping.
 */
class ${pascal}SupabaseRepository implements ${pascal}Repository {
  constructor(private readonly supabase: SupabaseClient) {}

  async findById(_id: string) {
    const { error } = await this.supabase.from("${table}").select("id").limit(1)
    if (error) {
      throw new SupabaseRepositoryError("Failed to load ${table}.", { cause: error })
    }
    return null
  }
}

export { ${pascal}SupabaseRepository }
`
  writeFileSync(path, body, "utf8")
  filesWritten.push(path)

  const portDir = join(
    repoRoot,
    "packages",
    "supabase-data",
    "src",
    "modules",
    domainId,
    "domain",
    "ports"
  )
  const portPath = join(portDir, `${entityKebab}-repository.port.ts`)
  if (!existsSync(portPath)) {
    mkdirSync(portDir, { recursive: true })
    const portBody = `import type { Database } from "@workspace/supabase-infra/types/database"

type ${pascal}Row = Database["public"]["Tables"]["${table}"]["Row"]

/** Codegen stub — narrow to a DTO and add methods as needed. */
interface ${pascal}Repository {
  findById(id: string): Promise<${pascal}Row | null>
}

export { type ${pascal}Repository }
`
    writeFileSync(portPath, portBody, "utf8")
    filesWritten.push(portPath)
  }

  return { errors, filesWritten }
}

function runLegacyStubsForDomainMap(opts: {
  checkOnly: boolean
  domainMap: DomainMapFile
  repoRoot: string
  filterDomainId?: string
  filterTable?: string
}): LegacyStubResult {
  const errors: string[] = []
  const filesWritten: string[] = []

  for (const domain of opts.domainMap.domains) {
    if (domain.codegen === false) {
      continue
    }
    if (opts.filterDomainId && domain.id !== opts.filterDomainId) {
      continue
    }
    for (const table of domain.tables) {
      if (opts.filterTable && table !== opts.filterTable) {
        continue
      }
      const r = emitLegacyStubForTable({
        checkOnly: opts.checkOnly,
        domainId: domain.id,
        repoRoot: opts.repoRoot,
        table,
      })
      errors.push(...r.errors)
      filesWritten.push(...r.filesWritten)
    }
  }

  return { errors, filesWritten }
}

export { emitLegacyStubForTable, runLegacyStubsForDomainMap }
