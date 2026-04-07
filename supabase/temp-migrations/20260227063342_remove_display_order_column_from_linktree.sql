-- migration-created-via: pnpm supabase:migration:new
-- created-at-utc: 2026-02-27T06:33:42Z
-- Migration: remove display_order column from linktree links
-- Purpose: Remove display_order column from public_linktree_links table
-- This column is deprecated and should not exist. Production doesn't have it.

-- Remove display_order column if it exists (idempotent)
DO $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name = 'public_linktree_links'
          AND column_name = 'display_order'
    ) THEN
        ALTER TABLE public.public_linktree_links DROP COLUMN display_order;
    END IF;
END $$;

-- Recreate function without display_order column reference
CREATE OR REPLACE FUNCTION public.get_psychologist_linktree_data(p_psychologist_id UUID)
RETURNS TABLE (
    id UUID,
    title TEXT,
    url TEXT,
    is_active BOOLEAN,
    sort_order INTEGER,
    created_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ
)
LANGUAGE SQL
SECURITY DEFINER
SET search_path = ''
AS $$
    SELECT
        id,
        title,
        url,
        is_active,
        sort_order,
        created_at,
        updated_at
    FROM public.public_linktree_links
    WHERE psychologist_id = p_psychologist_id
    ORDER BY sort_order ASC, created_at ASC;
$$;

-- Add comment documenting the removal
COMMENT ON TABLE public.public_linktree_links IS
'Links for psychologist public profiles (linktree). Uses sort_order for ordering.';
