-- migration-created-via: pnpm supabase:migration:new
-- Add composite index for efficient psychologist + day_of_week lookups
-- Supports onboarding configuration validation and weekly schedule queries

CREATE INDEX IF NOT EXISTS idx_psychologist_weekly_schedules_psychologist_day 
  ON public.psychologist_weekly_schedules (psychologist_id, day_of_week);

-- Add documentation comment
COMMENT ON INDEX idx_psychologist_weekly_schedules_psychologist_day IS 
  'Supports efficient lookup of weekly schedules by psychologist and day for onboarding checks';
