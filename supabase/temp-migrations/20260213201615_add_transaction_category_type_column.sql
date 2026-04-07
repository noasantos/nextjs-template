-- Migration: Add type column to financial_transaction_categories
-- This allows filtering categories by INCOME or EXPENSE in the transaction form.

-- The column 'type' already exists as a public.transaction_type enum, 
-- but we need to ensure it's correctly populated and used for filtering.

-- If the column didn't exist, we would add it:
-- ALTER TABLE public.financial_transaction_categories ADD COLUMN IF NOT EXISTS type public.transaction_type;

-- Update existing categories to ensure they have a type if they don't
UPDATE public.financial_transaction_categories 
SET type = 'INCOME' 
WHERE type IS NULL AND (name ILIKE '%receita%' OR name ILIKE '%sessão%' OR name ILIKE '%entrada%');

UPDATE public.financial_transaction_categories 
SET type = 'EXPENSE' 
WHERE type IS NULL AND (name ILIKE '%despesa%' OR name ILIKE '%gasto%' OR name ILIKE '%saída%' OR name ILIKE '%aluguel%' OR name ILIKE '%imposto%');

-- Default to INCOME for any remaining nulls (safety)
UPDATE public.financial_transaction_categories 
SET type = 'INCOME' 
WHERE type IS NULL;

-- Make the column NOT NULL if it isn't already
ALTER TABLE public.financial_transaction_categories ALTER COLUMN type SET NOT NULL;

-- Add a comment to the column
COMMENT ON COLUMN public.financial_transaction_categories.type IS 'Type of transaction this category belongs to (INCOME or EXPENSE).';

-- Note: Default financial transaction categories are now seeded via
-- supabase/seed.sql (reference values section) under the 'financial_transaction_category' category.
-- The INSERT statements previously here have been removed as they are now handled by seed files.
