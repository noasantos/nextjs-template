-- Migration: Add composite index on psychologist_clients for birthday calendar queries
-- Improves performance when filtering active patients with birth dates

-- Create composite index covering psychologist_id, status, and birth date columns
-- This index supports the birthday calendar layer queries efficiently under RLS
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_psychologist_clients_birthdays
ON public.psychologist_clients (psychologist_id, status)
WHERE (manual_date_of_birth IS NOT NULL OR synced_date_of_birth IS NOT NULL);
-- Add comment explaining the index purpose
COMMENT ON INDEX idx_psychologist_clients_birthdays IS 
'Composite index for birthday calendar queries. Covers psychologist_id + status with partial index on patients with birth dates.';
