BEGIN;
-- Legacy queue tables from pre-PGMQ architecture.
-- Canonical queue backend is pgmq.q_calendar_sync_queue via enqueue_calendar_sync_job().
DROP TABLE IF EXISTS public.google_sync_queue CASCADE;
DROP TABLE IF EXISTS public.sync_queue CASCADE;
COMMIT;
