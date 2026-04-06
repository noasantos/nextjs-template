/** Marker comment; files without this are never overwritten without --force. */
const CODEGEN_HEADER =
  "// @codegen-generated — do not hand-edit; regenerate with `pnpm codegen:backend --write`.\n\n"

function isCodegenManagedSource(content: string): boolean {
  return content.includes("@codegen-generated")
}

export { CODEGEN_HEADER, isCodegenManagedSource }
