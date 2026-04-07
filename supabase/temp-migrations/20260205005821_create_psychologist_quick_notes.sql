-- Migration: Create psychologist_quick_notes
-- Created at: 2026-02-05 00:58:21

-- =====================================================
-- 1. TABLE
-- =====================================================
CREATE TABLE IF NOT EXISTS public.psychologist_quick_notes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  psychologist_id UUID NOT NULL REFERENCES public.psychologists(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  priority TEXT NOT NULL DEFAULT 'none',
  due_date DATE,
  is_completed BOOLEAN NOT NULL DEFAULT false,
  completed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
ALTER TABLE public.psychologist_quick_notes
  ADD CONSTRAINT psychologist_quick_notes_priority_check
  CHECK (priority IN ('none', 'low', 'medium', 'high'));
-- =====================================================
-- 2. INDEXES
-- =====================================================
CREATE INDEX IF NOT EXISTS idx_psychologist_quick_notes_psychologist_id
  ON public.psychologist_quick_notes(psychologist_id);
CREATE INDEX IF NOT EXISTS idx_psychologist_quick_notes_due_date
  ON public.psychologist_quick_notes(due_date);
CREATE INDEX IF NOT EXISTS idx_psychologist_quick_notes_is_completed
  ON public.psychologist_quick_notes(is_completed);
-- =====================================================
-- 3. RLS
-- =====================================================
ALTER TABLE public.psychologist_quick_notes ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "psychologist_quick_notes_owner_access" ON public.psychologist_quick_notes;
CREATE POLICY "psychologist_quick_notes_owner_access"
ON public.psychologist_quick_notes
FOR ALL
TO authenticated
USING (psychologist_id = (select auth.uid()))
WITH CHECK (psychologist_id = (select auth.uid()));
