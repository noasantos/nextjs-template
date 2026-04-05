import type { DomainMapFile } from "./domain-map-schema"
import { extractPublicTableNames } from "./extract-public-table-names"

type SyncReport = {
  addedToTypes: string[]
  removedFromTypes: string[]
  text: string
}

function buildDomainMapSyncReport(
  domainMap: DomainMapFile,
  databaseTypesSource: string
): SyncReport {
  const currentTypes = new Set(extractPublicTableNames(databaseTypesSource))
  const mapped = new Set<string>()
  for (const d of domainMap.domains) {
    for (const t of d.tables) {
      mapped.add(t)
    }
  }
  for (const t of domainMap.ignoreTables ?? []) {
    mapped.add(t)
  }

  const addedToTypes: string[] = []
  for (const t of currentTypes) {
    if (!mapped.has(t)) {
      addedToTypes.push(t)
    }
  }

  const removedFromTypes: string[] = []
  for (const t of mapped) {
    if (!currentTypes.has(t)) {
      removedFromTypes.push(t)
    }
  }

  const lines = [
    "domain-map sync report (types vs domain-map.json)",
    "",
    `Tables in types but not in any domain or ignoreTables (${addedToTypes.length}):`,
    ...addedToTypes.map((t) => `  + ${t}`),
    "",
    `Tables in domain-map/ignore but missing from types (${removedFromTypes.length}):`,
    ...removedFromTypes.map((t) => `  - ${t}`),
    "",
  ]

  return {
    addedToTypes,
    removedFromTypes,
    text: lines.join("\n"),
  }
}

export { buildDomainMapSyncReport, type SyncReport }
