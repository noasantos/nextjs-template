# Repository standards (human contract)

This file is the **human-facing** entry for how we work in this monorepo. **AI
agents** should start at the root [`AGENTS.md`](../../AGENTS.md).

## Where to read next

- **[CONTRIBUTING.md](../CONTRIBUTING.md)** — Tooling, hooks, contribution flow
- **[Golden rules](./golden-rules.md)** — Non‑negotiable engineering rules
  (GR‑\*)
- **[Anti-patterns](./anti-patterns.md)** — Forbidden patterns (BAD‑\*)
- **[Package file suffixes](./package-file-suffixes.md)** — Composition package
  filenames (`brand`, `core`, `forms`, `seo`)

## Rules parity

Cursor rule sources live in **`.cursor/rules/*.mdc`** with mirrored copies under
**`docs/standards/rules/*.md`**. CI enforces parity:
`pnpm check:cursor-rules-parity`.
