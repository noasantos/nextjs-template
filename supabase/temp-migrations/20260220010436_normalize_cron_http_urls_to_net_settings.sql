-- Make pg_cron HTTP jobs environment-agnostic.
-- Replaces hardcoded project URLs with net._settings.supabase_url.

DO $$
DECLARE
  v_job record;
  v_command text;
BEGIN
  IF EXISTS (
    SELECT 1
    FROM pg_namespace
    WHERE nspname = 'cron'
  ) THEN
    FOR v_job IN
      SELECT jobid, command
      FROM cron.job
      WHERE command LIKE '%net.http_post%'
    LOOP
      v_command := v_job.command;

      v_command := regexp_replace(
        v_command,
        'url := ''https://[^'']+/functions/v1/trigger-periodic-sync''',
        'url := (SELECT value FROM net._settings WHERE name = ''supabase_url'') || ''/functions/v1/trigger-periodic-sync''',
        'g'
      );

      v_command := regexp_replace(
        v_command,
        'url := ''https://[^'']+/functions/v1/trigger-renew-watch-channels''',
        'url := (SELECT value FROM net._settings WHERE name = ''supabase_url'') || ''/functions/v1/trigger-renew-watch-channels''',
        'g'
      );

      v_command := regexp_replace(
        v_command,
        'url := ''https://[^'']+/functions/v1/process-pending-session-billing''',
        'url := (SELECT value FROM net._settings WHERE name = ''supabase_url'') || ''/functions/v1/process-pending-session-billing''',
        'g'
      );

      v_command := regexp_replace(
        v_command,
        'url := ''https://[^'']+/functions/v1/trigger-process-sync-queue''',
        'url := (SELECT value FROM net._settings WHERE name = ''supabase_url'') || ''/functions/v1/trigger-process-sync-queue''',
        'g'
      );

      v_command := replace(
        v_command,
        '''Authorization'', ''Bearer '' || current_setting(''app.settings.service_role_key'', true)',
        '''Authorization'', ''Bearer '' || (SELECT value FROM net._settings WHERE name = ''service_role_key'')'
      );

      IF v_command IS DISTINCT FROM v_job.command THEN
        PERFORM cron.alter_job(v_job.jobid, command := v_command);
      END IF;
    END LOOP;
  END IF;
END;
$$;
