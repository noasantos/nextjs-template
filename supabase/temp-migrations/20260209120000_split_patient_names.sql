-- Migration to split manual_full_name into manual_first_name, manual_last_name and add manual_display_name
-- Applied on: 2026-02-09

DO $$ 
BEGIN
    -- Add columns if they don't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'psychologist_clients' AND column_name = 'manual_first_name') THEN
        ALTER TABLE psychologist_clients ADD COLUMN manual_first_name TEXT;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'psychologist_clients' AND column_name = 'manual_last_name') THEN
        ALTER TABLE psychologist_clients ADD COLUMN manual_last_name TEXT;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'psychologist_clients' AND column_name = 'manual_display_name') THEN
        ALTER TABLE psychologist_clients ADD COLUMN manual_display_name TEXT;
    END IF;
END $$;
-- Migrate existing data from manual_full_name if first_name is empty
UPDATE psychologist_clients 
SET 
    manual_first_name = split_part(manual_full_name, ' ', 1),
    manual_last_name = substring(manual_full_name from position(' ' in manual_full_name) + 1),
    manual_display_name = manual_full_name
WHERE (manual_first_name IS NULL OR manual_first_name = '') AND manual_full_name IS NOT NULL AND manual_full_name != '';
-- Function to auto-generate display name 
-- This follows the pattern: 
-- 1. If compound name (First + Second), use those (e.g., "Ana Luiza")
-- 2. If simple name + last name, use those (e.g., "Ana Silva")
-- 3. Otherwise use just first name
CREATE OR REPLACE FUNCTION generate_patient_display_name()
RETURNS TRIGGER AS $$
DECLARE
    parts TEXT[];
BEGIN
    -- Only generate if display name is not manually provided
    IF NEW.manual_display_name IS NULL OR NEW.manual_display_name = '' THEN
        parts := regexp_split_to_array(trim(NEW.manual_first_name), '\s+');
        
        IF array_length(parts, 1) >= 2 THEN
            -- Compound name (at least 2 parts), take the first two
            NEW.manual_display_name := parts[1] || ' ' || parts[2];
        ELSIF NEW.manual_last_name IS NOT NULL AND NEW.manual_last_name != '' THEN
            -- Simple name + last name
            NEW.manual_display_name := NEW.manual_first_name || ' ' || NEW.manual_last_name;
        ELSE
            -- Simple name only
            NEW.manual_display_name := NEW.manual_first_name;
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;
-- Create trigger to always keep display name updated if not provided
DROP TRIGGER IF EXISTS trigger_generate_display_name ON psychologist_clients;
CREATE TRIGGER trigger_generate_display_name
BEFORE INSERT OR UPDATE OF manual_first_name, manual_last_name ON psychologist_clients
FOR EACH ROW
EXECUTE FUNCTION generate_patient_display_name();
