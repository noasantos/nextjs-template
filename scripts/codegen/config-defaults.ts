/**
 * Resolve config paths for codegen CLIs: prefer local gitignored files, else `*.example.json`.
 */
import { existsSync } from "node:fs"
import { resolve } from "node:path"

function resolveDomainMapPath(repoRoot: string, explicit?: string): string | undefined {
  if (explicit) {
    return resolve(repoRoot, explicit)
  }
  const local = resolve(repoRoot, "config/domain-map.json")
  const example = resolve(repoRoot, "config/domain-map.example.json")
  if (existsSync(local)) {
    return local
  }
  if (existsSync(example)) {
    return example
  }
  return undefined
}

function resolveRepositoryPlanPath(repoRoot: string, explicit?: string): string | undefined {
  if (explicit) {
    return resolve(repoRoot, explicit)
  }
  const local = resolve(repoRoot, "config/repository-plan.json")
  const example = resolve(repoRoot, "config/repository-plan.example.json")
  if (existsSync(local)) {
    return local
  }
  if (existsSync(example)) {
    return example
  }
  return undefined
}

export { resolveDomainMapPath, resolveRepositoryPlanPath }
