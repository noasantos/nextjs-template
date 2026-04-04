export type JsonLdType = Record<string, unknown>

/**
 * Serializes a JSON-LD object for use in `<script type="application/ld+json">`.
 * Use `dangerouslySetInnerHTML={{ __html: buildJsonLd(data) }}` in your page component.
 */
export function buildJsonLd(data: JsonLdType): string {
  return JSON.stringify(data)
}
