import * as ts from "typescript"

type TableBucket = "Tables" | "Views"

type ExtractedField = {
  name: string
  typeText: string
  isOptional: boolean
  isNullable: boolean
}

type ExtractedTableShapes = {
  insert: ExtractedField[]
  row: ExtractedField[]
  update: ExtractedField[]
}

function getPropertyType(
  members: readonly ts.TypeElement[],
  name: string
): ts.TypeNode | undefined {
  for (const member of members) {
    if (!ts.isPropertySignature(member) || !member.name) {
      continue
    }
    if (ts.isIdentifier(member.name) && member.name.text === name) {
      return member.type
    }
  }
  return undefined
}

function getNestedShape(
  sourceFile: ts.SourceFile,
  publicMembers: readonly ts.TypeElement[],
  bucket: TableBucket,
  entityName: string,
  shapeName: "Insert" | "Row" | "Update"
): ExtractedField[] {
  const bucketType = getPropertyType(publicMembers, bucket)
  if (!bucketType || !ts.isTypeLiteralNode(bucketType)) {
    return []
  }

  const entityType = getPropertyType(bucketType.members, entityName)
  if (!entityType || !ts.isTypeLiteralNode(entityType)) {
    return []
  }

  const shapeType = getPropertyType(entityType.members, shapeName)
  if (!shapeType || !ts.isTypeLiteralNode(shapeType)) {
    return []
  }

  return shapeType.members.flatMap((member) => {
    if (!ts.isPropertySignature(member) || !member.name || !ts.isIdentifier(member.name)) {
      return []
    }

    const typeText = member.type?.getText(sourceFile) ?? "unknown"
    return [
      {
        name: member.name.text,
        typeText,
        isNullable: /\bnull\b/.test(typeText),
        isOptional: Boolean(member.questionToken) || /\bundefined\b/.test(typeText),
      },
    ]
  })
}

function extractTableShapes(
  sourceText: string,
  entityName: string,
  bucket: TableBucket,
  fileName = "database.types.ts"
): ExtractedTableShapes {
  const sourceFile = ts.createSourceFile(
    fileName,
    sourceText,
    ts.ScriptTarget.Latest,
    true,
    ts.ScriptKind.TS
  )

  for (const statement of sourceFile.statements) {
    if (!ts.isTypeAliasDeclaration(statement) || statement.name.text !== "Database") {
      continue
    }

    const root = statement.type
    if (!ts.isTypeLiteralNode(root)) {
      continue
    }

    const publicType = getPropertyType(root.members, "public")
    if (!publicType || !ts.isTypeLiteralNode(publicType)) {
      continue
    }

    return {
      insert: getNestedShape(sourceFile, publicType.members, bucket, entityName, "Insert"),
      row: getNestedShape(sourceFile, publicType.members, bucket, entityName, "Row"),
      update: getNestedShape(sourceFile, publicType.members, bucket, entityName, "Update"),
    }
  }

  return {
    insert: [],
    row: [],
    update: [],
  }
}

export { extractTableShapes, type ExtractedField, type ExtractedTableShapes, type TableBucket }
