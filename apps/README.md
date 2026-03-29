# Applications

Example surface on the shared stack (**Next.js 16**, **Tailwind v4**, **Supabase**, etc. — full list in [docs/reference/stack.md](../docs/reference/stack.md)).

Before a **production** deploy, replace **“Example App”** (and related copy) in root metadata and the PWA manifest, set **`NEXT_PUBLIC_SITE_URL`** to your live **https** origin, and enable **`ROBOTS_ALLOW=true`** only on the environment you want indexed — see [docs/guides/seo.md](../docs/guides/seo.md) and [docs/checklists/seo-fork.md](../docs/checklists/seo-fork.md).

| Folder | Port (dev) | Description |
|--------|------------|-------------|
| `example` | 3000 | Template Next.js app: marketing and auth routes — rename when you ship a real product |

## Documentation under `apps/`

| Path | Role |
|------|------|
| **[`apps/docs/`](./docs/README.md)** | **Cross-app product / business** — domain concepts, flows, glossary ([GR-019](../docs/standards/golden-rules.md#gr-019-three-level-documentation-layout)) |
| **`apps/<app>/docs/`** | **Single-app** domain — routes, features, runbooks scoped to that app only |

Template engineering standards (agents, stack, migrations) stay in the monorepo root **`docs/`**, not here.

See [docs/architecture/overview.md](../docs/architecture/overview.md).
