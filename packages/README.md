# Packages (`@workspace/*`)

Shared libraries consumed by apps. **Agent entry:** [`AGENTS.md`](./AGENTS.md).

## Naming (composition packages)

Hooks, components, and providers in **`brand`**, **`core`**, **`forms`**, and
**`seo`** use explicit **filename suffixes** under `src/`. **`packages/ui`** is
excluded (shadcn-only).

**Read:**
[`docs/standards/package-file-suffixes.md`](../docs/standards/package-file-suffixes.md)

**Enforcement:** `pnpm check:forbidden`
