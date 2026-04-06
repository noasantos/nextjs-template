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

function rowPropertyNames(rowType: ts.TypeNode | undefined): string[] {
  if (!rowType || !ts.isTypeLiteralNode(rowType)) {
    return []
  }
  const names: string[] = []
  for (const m of rowType.members) {
    if (!ts.isPropertySignature(m) || !m.name || !ts.isIdentifier(m.name)) {
      continue
    }
    names.push(m.name.text)
  }
  return names
}

function getNestedTableOrView(
  publicMembers: readonly ts.TypeElement[],
  bucket: "Tables" | "Views",
  entityName: string
): ts.TypeNode | undefined {
  const bucketType = getPropertyType([...publicMembers], bucket)
  if (!bucketType || !ts.isTypeLiteralNode(bucketType)) {
    return
  }
  const entityType = getPropertyType([...bucketType.members], entityName)
  if (!entityType || !ts.isTypeLiteralNode(entityType)) {
    return
  }
  return getPropertyType([...entityType.members], "Row")
}

/**
 * Returns snake_case column names from `Database["public"]["Tables"][table]["Row"]`
 * or `Database["public"]["Views"][view]["Row"]`.
 */
function extractRowColumnNames(
  sourceText: string,
  entityName: string,
  bucket: "Tables" | "Views",
  fileName = "database.types.ts"
): string[] {
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
    const row = getNestedTableOrView(publicType.members, bucket, entityName)
    return rowPropertyNames(row)
  }

  return []
}

export { extractRowColumnNames }
