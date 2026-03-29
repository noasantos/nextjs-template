# Message files (`apps/example/messages`)

JSON dictionaries keyed by namespace (e.g. `Metadata`, `Marketing`, `Nav`). The active locale is chosen from the `[locale]` URL segment; `i18n/request.ts` loads `messages/<locale>.json`.

## Adding keys

1. Add the key to **every** locale file you ship (`en.json`, `pt.json`, …) to avoid missing translations.
2. Use **nested objects** for grouping (`Marketing.hero.heading`).
3. In **Server Components**, use `getTranslations('Namespace')` from `next-intl/server`.
4. In **Client Components**, use `useTranslations('Namespace')` from `next-intl`.

## TypeScript

`apps/example/global.d.ts` augments `next-intl` with `Messages: typeof en` so keys are checked against `en.json`. After large schema changes, keep JSON shapes aligned across locales.

## Fork note

For multiple deployable apps, consider moving shared messages and `defineRouting` to `packages/i18n` and importing from each app.
