-- migration-created-via: pnpm supabase:migration:new
-- created-at-utc: 2026-04-04T13:22:22Z
--
-- Performance: Add missing indexes on foreign key columns
-- to prevent full table scans on RLS policy checks and JOIN operations.
--
-- Missing indexes identified via schema audit:
-- 1. profiles.user_id → auth.users(id): RLS policies filter by user_id
-- 2. user_roles.role → app_roles(role): FK constraint, JOIN queries

-- Index on profiles.user_id for RLS policy: profiles_select_own_or_admin
-- Without this index, every SELECT on profiles does a full table scan
-- to evaluate (user_id = auth.uid()) OR auth_is_admin()
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_profiles_user_id
  ON public.profiles(user_id);

-- Index on user_roles.role for FK lookups and role-based filtering
-- Complements existing idx_user_roles_user_id for composite queries
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_user_roles_role
  ON public.user_roles(role);
