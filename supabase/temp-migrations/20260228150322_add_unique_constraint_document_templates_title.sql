-- migration-created-via: pnpm supabase:migration:new
-- created-at-utc: 2026-02-28T15:03:22Z
-- Migration: Add unique constraint on catalog_document_templates.title
-- Description: Enables ON CONFLICT DO UPDATE for document template seeds

-- Add unique constraint on title for idempotent seeding
-- This allows seed files to use ON CONFLICT (title) DO UPDATE pattern
ALTER TABLE public.catalog_document_templates
ADD CONSTRAINT catalog_document_templates_title_unique
UNIQUE (title);

-- Add comment explaining the constraint purpose
COMMENT ON CONSTRAINT catalog_document_templates_title_unique
ON public.catalog_document_templates
IS 'Enables idempotent seeding of document templates using ON CONFLICT DO UPDATE';
