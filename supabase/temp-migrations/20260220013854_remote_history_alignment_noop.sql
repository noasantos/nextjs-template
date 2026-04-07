-- No-op migration to align local migration directory with remote migration history.
-- Version exists in remote history table and must be present locally.

DO $$
BEGIN
  -- intentionally empty
  NULL;
END
$$;
