-- Migration to fix existing patient display names
-- Ensures all patients have correct display_name computed from the trigger logic

-- Recompute manual_display_name for all patients where it's NULL or incorrect
UPDATE public.psychologist_clients
SET manual_display_name = public.compute_short_display_name(
  COALESCE(NULLIF(btrim(manual_preferred_name), ''), manual_first_name),
  manual_last_name
)
WHERE (manual_first_name IS NOT NULL OR manual_preferred_name IS NOT NULL)
  AND (
    manual_display_name IS NULL 
    OR manual_display_name = ''
    OR manual_display_name = manual_full_name -- Fix cases where full name was incorrectly used
  );
-- Add comment explaining the display name logic
COMMENT ON COLUMN public.psychologist_clients.manual_display_name IS 
'Auto-generated display name following the rule: 
- If name is compound (≥2 words): use compound name (e.g., "Ana Luiza")
- If simple name + surname: use name + last surname word (e.g., "Ana Silva")
- If only name: use name only (e.g., "Ana")
Priority: manual_preferred_name → manual_first_name';
