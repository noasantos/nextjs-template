import * as ts from "typescript"

function getPropertyType(
  members: readonly ts.TypeElement[],
  name: string
): ts.TypeNode | undefined {
  for (const m of members) {
    if (!ts.isPropertySignature(m) || !m.name) {
      continue
    }
    if (ts.isIdentifier(m.name) && m.name.text === name) {
      return m.type
    }
  }
  return
}

function tableNamesFromTablesType(tablesType: ts.TypeNode | undefined): string[] {
  if (!tablesType || !ts.isTypeLiteralNode(tablesType)) {
    return []
  }
  const names: string[] = []
  for (const m of tablesType.members) {
    if (ts.isPropertySignature(m) && m.name && ts.isIdentifier(m.name)) {
      names.push(m.name.text)
    }
  }
  return names
}

/**
 * Reads Supabase-generated `database.types.ts` and returns `public.Tables` keys.
 */
function extractPublicTableNames(sourceText: string, fileName = "database.types.ts"): string[] {
  const sourceFile = ts.createSourceFile(
    fileName,
    sourceText,
    ts.ScriptTarget.Latest,
    true,
    ts.ScriptKind.TS
  )

  for (const stmt of sourceFile.statements) {
    if (!ts.isTypeAliasDeclaration(stmt) || stmt.name.text !== "Database") {
      continue
    }
    const root = stmt.type
    if (!ts.isTypeLiteralNode(root)) {
      continue
    }
    const publicType = getPropertyType([...root.members], "public")
    if (!publicType || !ts.isTypeLiteralNode(publicType)) {
      continue
    }
    const tablesType = getPropertyType([...publicType.members], "Tables")
    return tableNamesFromTablesType(tablesType)
  }

  return []
}

export { extractPublicTableNames }
