-- migration-created-via: pnpm supabase:migration:new
-- Limit registered_specialties to at most 2 items in public_profiles table

ALTER TABLE public.public_profiles
ADD CONSTRAINT registered_specialties_limit
CHECK (cardinality(registered_specialties) <= 2);

-- Also add to marketplace_psychologist_profiles if it exists and has the same column
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'marketplace_psychologist_profiles' AND column_name = 'registered_specialties') THEN
        ALTER TABLE public.marketplace_psychologist_profiles
        ADD CONSTRAINT registered_specialties_limit_marketplace
        CHECK (cardinality(registered_specialties) <= 2);
    END IF;
END $$;
