# Repository Hygiene

Default automation for dependency and secret safety.

## Supply chain

- Dependabot updates `npm` dependencies and GitHub Actions on a weekly cadence.
- Pull requests run GitHub dependency review to surface risky dependency deltas.
- CodeQL scans JavaScript/TypeScript on PRs and the default branch.

## Secrets

- Never commit service-role keys, access tokens, or production credentials.
- Keep browser-safe variables under `NEXT_PUBLIC_*`; everything else is server-only.
- `.env.example` documents expected variables, but real values belong in `.env.local` or your platform secret store.
- Local agent workflows should not add `SUPABASE_SERVICE_ROLE_KEY` to committed env files; the local Supabase setup resolves it when appropriate.

## Template expectation

These workflows are generic on purpose. Fork maintainers can tighten schedules, labels, and branch targets without changing the underlying contract.
