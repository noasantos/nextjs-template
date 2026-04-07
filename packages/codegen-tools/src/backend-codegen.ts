import { resolve } from "node:path"

export {
  planDtoBasename,
  planDtoImportSpecifier,
  planMapperBasename,
  planMapperImportSpecifier,
  planModuleEntityKebab,
  planPortBasename,
  planPortImportSpecifier,
  planRepositoryBasename,
  planRepositoryImportSpecifier,
  planRepositoryIntegrationTestBasename,
  SUPABASE_DATA_MODULES_IMPORT_PREFIX,
} from "./backend-codegen/plan-module-paths"
export {
  runBackendCodegen,
  repositoryPath,
  type BackendCodegenResult,
  type BackendCodegenOptions,
} from "./backend-codegen/run"

function resolveRepoRoot(cwd: string): string {
  return resolve(cwd)
}

export { resolveRepoRoot }
