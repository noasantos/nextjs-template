-- migration-created-via: pnpm supabase:migration:new
-- Migration: create_get_psychologist_linktree_data_function
-- Created at: 2026-02-23T18:59:43Z
-- Purpose: Create RPC function to retrieve linktree links for a psychologist

-- Create function to get psychologist linktree data
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

-- Add comment
COMMENT ON FUNCTION public.get_psychologist_linktree_data(UUID) IS 
'Retrieves all linktree links for a specific psychologist. Used by the marketplace/public profile feature.';
