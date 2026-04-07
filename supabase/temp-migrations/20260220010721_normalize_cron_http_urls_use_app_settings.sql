-- Normalize pg_cron HTTP jobs to use app.settings values.
-- Local-safe fallback avoids any production URL hardcoding.

DO $$
DECLARE
  v_job record;
  v_command text;
  v_base_url_expr constant text :=
    'COALESCE(NULLIF(current_setting(''app.settings.supabase_url'', true), ''''), ''http://host.docker.internal:54321'')';
  v_service_key_expr constant text :=
    'COALESCE(NULLIF(current_setting(''app.settings.service_role_key'', true), ''''), '''')';
BEGIN
  IF EXISTS (SELECT 1 FROM pg_namespace WHERE nspname = 'cron') THEN
    FOR v_job IN
      SELECT jobid, command
      FROM cron.job
      WHERE command LIKE '%net.http_post%'
    LOOP
      v_command := v_job.command;

      -- Upgrade from net._settings-based form
      v_command := replace(
        v_command,
        '(SELECT value FROM net._settings WHERE name = ''supabase_url'')',
        v_base_url_expr
      );

      v_command := replace(
        v_command,
        '(SELECT value FROM net._settings WHERE name = ''service_role_key'')',
        v_service_key_expr
      );

      -- Upgrade from hardcoded project URL form (if any still exists)
      v_command := regexp_replace(
        v_command,
        'url := ''https://[^'']+/functions/v1/trigger-periodic-sync''',
        'url := ' || v_base_url_expr || ' || ''/functions/v1/trigger-periodic-sync''',
        'g'
      );

      v_command := regexp_replace(
        v_command,
        'url := ''https://[^'']+/functions/v1/trigger-renew-watch-channels''',
        'url := ' || v_base_url_expr || ' || ''/functions/v1/trigger-renew-watch-channels''',
        'g'
      );

      v_command := regexp_replace(
        v_command,
        'url := ''https://[^'']+/functions/v1/process-pending-session-billing''',
        'url := ' || v_base_url_expr || ' || ''/functions/v1/process-pending-session-billing''',
        'g'
      );

      v_command := regexp_replace(
        v_command,
        'url := ''https://[^'']+/functions/v1/trigger-process-sync-queue''',
        'url := ' || v_base_url_expr || ' || ''/functions/v1/trigger-process-sync-queue''',
        'g'
      );

      -- Normalize auth header expression
      v_command := replace(
        v_command,
        '''Authorization'', ''Bearer '' || current_setting(''app.settings.service_role_key'', true)',
        '''Authorization'', ''Bearer '' || ' || v_service_key_expr
      );

      IF v_command IS DISTINCT FROM v_job.command THEN
        PERFORM cron.alter_job(v_job.jobid, command := v_command);
      END IF;
    END LOOP;
  END IF;
END;
$$;
