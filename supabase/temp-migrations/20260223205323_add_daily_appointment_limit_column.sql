-- migration-created-via: pnpm supabase:migration:new
-- Add daily_appointment_limit column to psychologist_weekly_schedules
-- This column limits appointments per time interval per day (NULL = unlimited)

ALTER TABLE public.psychologist_weekly_schedules
ADD COLUMN IF NOT EXISTS daily_appointment_limit INTEGER DEFAULT NULL;

-- Add documentation comment
COMMENT ON COLUMN public.psychologist_weekly_schedules.daily_appointment_limit IS 
  'Maximum number of appointments allowed for this time interval per day. NULL means unlimited.';
