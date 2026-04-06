import { join } from "node:path"

function entityKebab(table: string): string {
  return table.replace(/_/g, "-")
}

function moduleRoot(repoRoot: string, domainId: string): string {
  return join(repoRoot, "packages", "supabase-data", "src", "modules", domainId)
}

function dtoPath(repoRoot: string, domainId: string, table: string): string {
  const kebab = entityKebab(table)
  return join(moduleRoot(repoRoot, domainId), "domain", "dto", `${kebab}.dto.ts`)
}

function mapperPath(repoRoot: string, domainId: string, table: string): string {
  const kebab = entityKebab(table)
  return join(moduleRoot(repoRoot, domainId), "infrastructure", "mappers", `${kebab}.mapper.ts`)
}

function portPath(repoRoot: string, domainId: string, table: string): string {
  const kebab = entityKebab(table)
  return join(moduleRoot(repoRoot, domainId), "domain", "ports", `${kebab}-repository.port.ts`)
}

function repositoryPath(repoRoot: string, domainId: string, table: string): string {
  const kebab = entityKebab(table)
  return join(
    moduleRoot(repoRoot, domainId),
    "infrastructure",
    "repositories",
    `${kebab}-supabase.repository.ts`
  )
}

/**
 * Skipped integration scaffold path (relative to repo root).
 * Mirrors `packages/supabase-data/src/modules/<domainId>/` under
 * `tests/integration/supabase-data/modules/<domainId>/`.
 */
function integrationTestPath(repoRoot: string, domainId: string, table: string): string {
  const kebab = entityKebab(table)
  return join(
    repoRoot,
    "tests",
    "integration",
    "supabase-data",
    "modules",
    domainId,
    `${kebab}.repository.codegen.integration.test.ts`
  )
}

export {
  dtoPath,
  entityKebab,
  integrationTestPath,
  mapperPath,
  moduleRoot,
  portPath,
  repositoryPath,
}
