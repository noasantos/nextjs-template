import { join } from "node:path"

import {
  planDtoBasename,
  planMapperBasename,
  planModuleEntityKebab,
  planPortBasename,
  planRepositoryBasename,
  planRepositoryIntegrationTestBasename,
} from "./plan-module-paths"

function entityKebab(table: string): string {
  return planModuleEntityKebab(table)
}

function moduleRoot(repoRoot: string, domainId: string): string {
  return join(repoRoot, "packages", "supabase-data", "src", "modules", domainId)
}

/** Suffix `.codegen.ts` keeps module artifacts removable via `pnpm codegen:clean`. */
function dtoPath(repoRoot: string, domainId: string, table: string): string {
  const kebab = planModuleEntityKebab(table)
  return join(moduleRoot(repoRoot, domainId), "domain", "dto", planDtoBasename(kebab))
}

function mapperPath(repoRoot: string, domainId: string, table: string): string {
  const kebab = planModuleEntityKebab(table)
  return join(
    moduleRoot(repoRoot, domainId),
    "infrastructure",
    "mappers",
    planMapperBasename(kebab)
  )
}

function portPath(repoRoot: string, domainId: string, table: string): string {
  const kebab = planModuleEntityKebab(table)
  return join(moduleRoot(repoRoot, domainId), "domain", "ports", planPortBasename(kebab))
}

function repositoryPath(repoRoot: string, domainId: string, table: string): string {
  const kebab = planModuleEntityKebab(table)
  return join(
    moduleRoot(repoRoot, domainId),
    "infrastructure",
    "repositories",
    planRepositoryBasename(kebab)
  )
}

/**
 * Skipped integration scaffold path (relative to repo root).
 * Mirrors `packages/supabase-data/src/modules/<domainId>/` under
 * `tests/integration/supabase-data/modules/<domainId>/`.
 */
function integrationTestPath(repoRoot: string, domainId: string, table: string): string {
  const kebab = planModuleEntityKebab(table)
  return join(
    repoRoot,
    "tests",
    "integration",
    "supabase-data",
    "modules",
    domainId,
    planRepositoryIntegrationTestBasename(kebab)
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
