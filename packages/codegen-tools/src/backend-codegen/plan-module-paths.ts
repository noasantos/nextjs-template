/**
 * Single source of truth for **plan-driven** `@workspace/supabase-data` module
 * file basenames and TypeScript import specifiers (no `.ts` suffix).
 *
 * Basenames include a `.codegen` segment so `pnpm codegen:clean` can delete them.
 * Hand modules (`profiles`, `user-access`, `user-roles`) keep plain names — not covered here.
 */

/** Import prefix for `package.json` exports `./modules/*`. */
export const SUPABASE_DATA_MODULES_IMPORT_PREFIX = "@workspace/supabase-data/modules" as const

/** Table name in snake_case → kebab segment used in filenames and imports. */
export function planModuleEntityKebab(tableSnake: string): string {
  return tableSnake.replace(/_/g, "-")
}

export function planDtoBasename(entityKebab: string): string {
  return `${entityKebab}.dto.codegen.ts`
}

export function planMapperBasename(entityKebab: string): string {
  return `${entityKebab}.mapper.codegen.ts`
}

export function planPortBasename(entityKebab: string): string {
  return `${entityKebab}-repository.port.codegen.ts`
}

export function planRepositoryBasename(entityKebab: string): string {
  return `${entityKebab}-supabase.repository.codegen.ts`
}

export function planRepositoryIntegrationTestBasename(entityKebab: string): string {
  return `${entityKebab}.repository.codegen.integration.test.ts`
}

function moduleSubpath(domainId: string, rest: string): string {
  return `${SUPABASE_DATA_MODULES_IMPORT_PREFIX}/${domainId}/${rest}`
}

/** E.g. `@workspace/supabase-data/modules/catalog/domain/dto/session-types.dto.codegen` */
export function planDtoImportSpecifier(domainId: string, entityKebab: string): string {
  return moduleSubpath(domainId, `domain/dto/${entityKebab}.dto.codegen`)
}

export function planMapperImportSpecifier(domainId: string, entityKebab: string): string {
  return moduleSubpath(domainId, `infrastructure/mappers/${entityKebab}.mapper.codegen`)
}

export function planPortImportSpecifier(domainId: string, entityKebab: string): string {
  return moduleSubpath(domainId, `domain/ports/${entityKebab}-repository.port.codegen`)
}

export function planRepositoryImportSpecifier(domainId: string, entityKebab: string): string {
  return moduleSubpath(
    domainId,
    `infrastructure/repositories/${entityKebab}-supabase.repository.codegen`
  )
}
