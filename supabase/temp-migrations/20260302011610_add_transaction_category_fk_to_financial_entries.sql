-- migration-created-via: pnpm supabase:migration:new
-- Add foreign key constraint from psychologist_financial_entries to reference_values
-- for the transaction_category_id column

-- First, clean up orphaned references to prevent FK constraint violations
UPDATE psychologist_financial_entries
SET transaction_category_id = NULL
WHERE transaction_category_id IS NOT NULL
  AND transaction_category_id NOT IN (
    SELECT id FROM reference_values
  );

-- Then add the foreign key constraint
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'psychologist_financial_entries_transaction_category_id_fkey'
  ) THEN
    ALTER TABLE psychologist_financial_entries
      ADD CONSTRAINT psychologist_financial_entries_transaction_category_id_fkey
      FOREIGN KEY (transaction_category_id)
      REFERENCES reference_values(id)
      ON DELETE SET NULL;
  END IF;
END $$;

COMMENT ON CONSTRAINT psychologist_financial_entries_transaction_category_id_fkey 
  ON psychologist_financial_entries IS 'Links financial entry to transaction category in reference_values table';
