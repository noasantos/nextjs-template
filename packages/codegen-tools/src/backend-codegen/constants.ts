/** First-line marker; files without this (or legacy tag) are not overwritten without --force. */
const CODEGEN_HEADER =
  "// codegen:backend — do not hand-edit; regenerate with `pnpm codegen:backend --write`.\n\n"

function isCodegenManagedSource(content: string): boolean {
  return content.includes("codegen:backend —") || content.includes("@codegen-generated")
}

export { CODEGEN_HEADER, isCodegenManagedSource }
