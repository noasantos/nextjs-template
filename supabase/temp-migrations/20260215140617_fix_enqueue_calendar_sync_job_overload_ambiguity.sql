-- Fix PostgREST RPC ambiguity for enqueue_calendar_sync_job.
-- Keep only the canonical 3-argument signature.

DROP FUNCTION IF EXISTS public.enqueue_calendar_sync_job(jsonb, integer);
NOTIFY pgrst, 'reload schema';
