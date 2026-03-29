# Supabase Performance Guardrails

Keep these checks lightweight and repeatable.

## Query shape

- Select only the columns the caller needs. Avoid `select("*")`.
- Keep repository select lists explicit so reviews can spot over-fetch.
- Prefer one well-shaped query over multiple round trips when the policy and index shape still stay clear.

## RLS and indexes

- Add indexes for columns used in common filters, joins, and RLS predicates.
- Re-check index coverage when a policy starts filtering on a new column.
- Treat helper functions inside policies as performance-sensitive code, not “free” abstractions.

## When performance is in doubt

1. Reproduce the exact query against local Supabase.
2. Run `EXPLAIN` or `EXPLAIN ANALYZE`.
3. Check whether policy predicates and join/filter columns have index support.
4. Measure before changing schema or SQL shape.

The baseline migration already indexes `public.user_roles.user_id`, which matches both ordinary lookups and policy-oriented access checks.
