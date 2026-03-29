# Template fork notes

When you fork this repo for a real product:

- **`apps/example/**`** — rename the folder and `package.json` `name` to your app slug; trim routes you do not need (e.g. admin modules, `admin-nav-data`).
- **Env** — set `NEXT_PUBLIC_AUTH_APP_URL` to your app origin; set `NEXT_PUBLIC_SITE_URL` to your canonical **https** marketing origin (may match auth URL for single-app setups). Use `ROBOTS_ALLOW=true` only on production. See root [`.env.example`](../.env.example), [seo.md](./seo.md), and [preview-environments.md](./preview-environments.md).
