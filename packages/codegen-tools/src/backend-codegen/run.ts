/* oxlint-disable eslint-plugin-import/no-relative-parent-imports -- internal package subfolder */
/* oxlint-disable complexity -- orchestrates legacy vs plan paths */
import { existsSync, readFileSync } from "node:fs"
import { resolve } from "node:path"

import { parseDomainMapJson } from "../domain-map-schema"
import { extractRowColumnNames } from "../extract-table-row-columns"
import { mergeAndValidateRepositoryPlan, entryKey } from "../merge-repository-plan"
import { parseRepositoryPlanJson, type RepositoryPlanFile } from "../repository-plan-schema"
import { emitFromPlan } from "./emit-from-plan"
import { emitLegacyStubForTable } from "./legacy-stub"
import { repositoryPath } from "./paths"

export type CodegenMode = "legacy" | "strict"

export type BackendCodegenOptions = {
  checkOnly: boolean
  domainMapPath: string
  repoRoot: string
  /** Default: packages/supabase-infra canonical types */
  typesPath?: string
  /** When set and file exists, merged entries drive plan-based emit */
  planPath?: string
  mode?: CodegenMode
  filterDomainId?: string
  filterTable?: string
  force?: boolean
}

export type BackendCodegenResult = {
  errors: string[]
  filesWritten: string[]
  ok: boolean
  codegenEnabledDomainCount: number
  codegenEnabledTableCount: number
}

function loadTypesPath(repoRoot: string, explicit?: string): string {
  return explicit ?? resolve(repoRoot, "packages/supabase-infra/src/types/database.types.ts")
}

function loadPlan(path: string): RepositoryPlanFile | null {
  if (!existsSync(path)) {
    return null
  }
  const raw = JSON.parse(readFileSync(path, "utf8")) as unknown
  return parseRepositoryPlanJson(raw)
}

function columnsForEntry(
  databaseTypesSource: string,
  entry: import("../repository-plan-schema").RepositoryPlanEntry
): string[] {
  const bucket = entry.read.kind === "view" ? "Views" : "Tables"
  if (entry.dto.include === "all_columns") {
    return extractRowColumnNames(databaseTypesSource, entry.read.name, bucket)
  }
  return [...entry.dto.include.columns]
}

function runBackendCodegen(opts: BackendCodegenOptions): BackendCodegenResult {
  const errors: string[] = []
  const filesWritten: string[] = []
  let codegenEnabledDomainCount = 0
  let codegenEnabledTableCount = 0

  let domainMap
  try {
    const raw = JSON.parse(readFileSync(opts.domainMapPath, "utf8")) as unknown
    domainMap = parseDomainMapJson(raw)
  } catch (e) {
    return {
      errors: [`Failed to read or parse domain map: ${String(e)}`],
      filesWritten,
      ok: false,
      codegenEnabledDomainCount: 0,
      codegenEnabledTableCount: 0,
    }
  }

  for (const domain of domainMap.domains) {
    if (domain.codegen === false) {
      continue
    }
    codegenEnabledDomainCount += 1
    codegenEnabledTableCount += domain.tables.length
  }

  const typesSource = readFileSync(loadTypesPath(opts.repoRoot, opts.typesPath), "utf8")
  const mode = opts.mode ?? "legacy"
  const planPath = opts.planPath

  if (mode === "strict" && planPath && !existsSync(planPath)) {
    return {
      errors: [`Strict mode requires repository plan at ${planPath}`],
      filesWritten,
      ok: false,
      codegenEnabledDomainCount,
      codegenEnabledTableCount,
    }
  }

  let plan: RepositoryPlanFile | null = null
  if (planPath && existsSync(planPath)) {
    try {
      plan = loadPlan(planPath)
    } catch (e) {
      return {
        errors: [`Failed to parse repository plan: ${String(e)}`],
        filesWritten,
        ok: false,
        codegenEnabledDomainCount,
        codegenEnabledTableCount,
      }
    }
  }

  let mergedEntries = new Map<string, import("../repository-plan-schema").RepositoryPlanEntry>()

  if (plan) {
    const mergeOpts: Parameters<typeof mergeAndValidateRepositoryPlan>[0] = {
      databaseTypesSource: typesSource,
      domainMap,
      plan,
      strict: mode === "strict",
    }
    if (typeof opts.filterDomainId === "string") {
      mergeOpts.filterDomainId = opts.filterDomainId
    }
    if (typeof opts.filterTable === "string") {
      mergeOpts.filterTable = opts.filterTable
    }
    const merged = mergeAndValidateRepositoryPlan(mergeOpts)
    if (!merged.ok) {
      return {
        errors: merged.errors,
        filesWritten,
        ok: false,
        codegenEnabledDomainCount,
        codegenEnabledTableCount,
      }
    }
    mergedEntries = merged.entriesByKey
  }

  const filterDomain = opts.filterDomainId
  const filterTable = opts.filterTable

  for (const domain of domainMap.domains) {
    if (domain.codegen === false) {
      continue
    }
    if (filterDomain && domain.id !== filterDomain) {
      continue
    }
    for (const table of domain.tables) {
      if (filterTable && table !== filterTable) {
        continue
      }
      const k = entryKey(domain.id, table)
      const entry = mergedEntries.get(k)
      if (entry) {
        const cols = columnsForEntry(typesSource, entry)
        if (cols.length === 0) {
          errors.push(`No columns resolved for plan entry ${k}; check dto.include / types file`)
          continue
        }
        const r = emitFromPlan({
          checkOnly: opts.checkOnly,
          domainId: domain.id,
          entry,
          repoRoot: opts.repoRoot,
          columns: cols,
          force: opts.force === true,
        })
        errors.push(...r.errors)
        filesWritten.push(...r.filesWritten)
      } else {
        const legacy = emitLegacyStubForTable({
          checkOnly: opts.checkOnly,
          domainId: domain.id,
          repoRoot: opts.repoRoot,
          table,
        })
        errors.push(...legacy.errors)
        filesWritten.push(...legacy.filesWritten)
      }
    }
  }

  return {
    errors,
    filesWritten,
    ok: errors.length === 0,
    codegenEnabledDomainCount,
    codegenEnabledTableCount,
  }
}

export { repositoryPath, runBackendCodegen }
