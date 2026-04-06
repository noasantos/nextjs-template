# Template baseline SQL (reference only)

Files here are **not** executed by `supabase db reset`. They are the **canonical
starting point** for a greenfield Supabase project using this template’s
identity and observability model.

| File                                  | Purpose                                                                                                                                                                                                                                                                                                                               |
| ------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `0001_identity_and_observability.sql` | `profiles` (subscription jsonb, `access_version`), `app_roles`, `user_roles`, `subscription_claims_for_jwt` + `get_user_access_payload*` + `custom_access_token_hook` (JWT: whitelisted subscription snapshot, roles, `access_version`, optional permissions), `sync_user_roles`, `sync_profile_subscription`, `observability_events` |
| `0002_role_extension_pattern.sql`     | Comments + optional pattern for multi-role apps (e.g. provider vs patient profiles)                                                                                                                                                                                                                                                   |

**How to use:** see
[docs/guides/template-baseline-schema.md](../../docs/guides/template-baseline-schema.md).

**This repository** already has a full product history under
`supabase/migrations/`; do not duplicate this file as a second baseline unless
you are forking a new DB from scratch.
