import { resolve } from "node:path"

export {
  runBackendCodegen,
  repositoryPath,
  type BackendCodegenResult,
  type BackendCodegenOptions,
  type CodegenMode,
} from "./backend-codegen/run"

function resolveRepoRoot(cwd: string): string {
  return resolve(cwd)
}

export { resolveRepoRoot }
