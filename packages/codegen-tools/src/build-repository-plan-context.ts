import type { DomainMapFile } from "./domain-map-schema"
import { extractPublicTableNames } from "./extract-public-table-names"
import { extractPublicViewNames } from "./extract-public-view-names"

type RepositoryPlanContextOptions = {
  databaseTypesSource: string
  domainMap: DomainMapFile
  filterDomainId?: string
  filterTable?: string
  /** When set, included as `domainMapSyncReport` (from `buildDomainMapSyncReport`). */
  syncReportText?: string
}

/**
 * JSON string for semantic planning: `publicTables`, `publicViews`, `codegenDomains`.
 * Consumed by the coding agent with `prompts/repository-plan/v1.md` to author
 * `config/repository-plan.json`; deterministic codegen follows.
 */
function buildRepositoryPlanContext(opts: RepositoryPlanContextOptions): string {
  const tables = extractPublicTableNames(opts.databaseTypesSource)
  const views = extractPublicViewNames(opts.databaseTypesSource)

  const domains = opts.domainMap.domains
    .filter((d) => d.codegen !== false)
    .filter((d) => (opts.filterDomainId ? d.id === opts.filterDomainId : true))
    .map((d) => ({
      id: d.id,
      readOnly: d.readOnly,
      tables: opts.filterTable ? d.tables.filter((t) => t === opts.filterTable) : d.tables,
    }))
    .filter((d) => d.tables.length > 0)

  const payload: Record<string, unknown> = {
    publicTables: tables,
    publicViews: views,
    codegenDomains: domains,
  }
  if (opts.syncReportText !== undefined && opts.syncReportText.length > 0) {
    payload.domainMapSyncReport = opts.syncReportText
  }

  return JSON.stringify(payload, null, 2)
}

export { buildRepositoryPlanContext, type RepositoryPlanContextOptions }
