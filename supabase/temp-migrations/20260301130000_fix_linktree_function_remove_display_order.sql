-- migration-created-via: pnpm supabase:migration:new
-- created-at-utc: 2026-03-01T13:00:00Z
-- Migration: fix_linktree_function_remove_display_order
-- Purpose: Fix get_psychologist_linktree_data function to not reference display_order column

-- Drop and recreate function without display_order column reference
DROP FUNCTION IF EXISTS public.get_psychologist_linktree_data(UUID);

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

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION public.get_psychologist_linktree_data(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_psychologist_linktree_data(UUID) TO service_role;
GRANT EXECUTE ON FUNCTION public.get_psychologist_linktree_data(UUID) TO anon;
