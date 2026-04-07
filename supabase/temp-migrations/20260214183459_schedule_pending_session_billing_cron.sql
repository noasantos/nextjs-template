SELECT cron.schedule(
  'trigger-process-pending-session-billing',
  '0 * * * *',
  $$SELECT net.http_post(
      url := 'https://ecilqoemhxilnddugrql.supabase.co/functions/v1/process-pending-session-billing',
      headers := jsonb_build_object('Content-Type', 'application/json', 'Authorization', 'Bearer ' || current_setting('app.settings.service_role_key', true)),
      body := '{"limit": 200, "leadDays": 7}'
  );$$
);
