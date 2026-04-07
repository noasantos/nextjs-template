-- migration-created-via: pnpm supabase:migration:new
-- created-at-utc: 2026-04-06T17:06:35Z

CREATE EXTENSION IF NOT EXISTS moddatetime SCHEMA extensions;
CREATE EXTENSION IF NOT EXISTS btree_gist SCHEMA extensions;
CREATE EXTENSION IF NOT EXISTS pg_cron;
