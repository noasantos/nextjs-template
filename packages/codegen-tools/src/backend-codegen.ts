import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs"
import { dirname, join, resolve } from "node:path"

import type { DomainMapFile } from "./domain-map-schema"
import { parseDomainMapJson } from "./domain-map-schema"

type BackendCodegenOptions = {
  checkOnly: boolean
  domainMapPath: string
  repoRoot: string
}

type BackendCodegenResult = { errors: string[]; filesWritten: string[]; ok: boolean }

function pascalFromSnakeTable(table: string): string {
  return table
    .split("_")
    .map((p) => p.charAt(0).toUpperCase() + p.slice(1).toLowerCase())
    .join("")
}

function repositoryPath(repoRoot: string, domainId: string, table: string): string {
  const entityKebab = table.replace(/_/g, "-")
  return join(
    repoRoot,
    "packages",
    "supabase-data",
    "src",
    "modules",
    domainId,
    "infrastructure",
    "repositories",
    `${entityKebab}-supabase.repository.ts`
  )
}

function runBackendCodegen(opts: BackendCodegenOptions): BackendCodegenResult {
  const errors: string[] = []
  const filesWritten: string[] = []

  let domainMap: DomainMapFile
  try {
    const raw = JSON.parse(readFileSync(opts.domainMapPath, "utf8")) as unknown
    domainMap = parseDomainMapJson(raw)
  } catch (e) {
    return {
      errors: [`Failed to read or parse domain map: ${String(e)}`],
      filesWritten,
      ok: false,
    }
  }

  for (const domain of domainMap.domains) {
    if (domain.codegen === false) {
      continue
    }
    for (const table of domain.tables) {
      const path = repositoryPath(opts.repoRoot, domain.id, table)
      if (existsSync(path)) {
        continue
      }
      if (opts.checkOnly) {
        errors.push(`Missing generated repository (run without --check --write): ${path}`)
        continue
      }
      const pascal = pascalFromSnakeTable(table)
      const entityKebab = table.replace(/_/g, "-")
      const portRelativeImport = [
        "..",
        "..",
        "domain",
        "ports",
        `${entityKebab}-repository.port`,
      ].join("/")
      mkdirSync(dirname(path), { recursive: true })
      const body = `import type { SupabaseClient } from "@supabase/supabase-js"

import { SupabaseRepositoryError } from "@workspace/supabase-data/lib/supabase-repository-error"

import type { ${pascal}Repository } from "${portRelativeImport}"

/**
 * Codegen stub for table "${table}" (domain "${domain.id}").
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
        opts.repoRoot,
        "packages",
        "supabase-data",
        "src",
        "modules",
        domain.id,
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
    }
  }

  return { errors, filesWritten, ok: errors.length === 0 }
}

function resolveRepoRoot(cwd: string): string {
  return resolve(cwd)
}

export { repositoryPath, resolveRepoRoot, runBackendCodegen, type BackendCodegenResult }
