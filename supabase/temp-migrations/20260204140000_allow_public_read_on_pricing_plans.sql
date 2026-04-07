-- Migration: Allow public read access to stripe_price_plans
-- This is needed for the pricing page to work before user is fully authenticated
-- Created: 2026-02-04

-- Drop existing policy if exists
DROP POLICY IF EXISTS stripe_price_plans_select_all ON public.stripe_price_plans;
DROP POLICY IF EXISTS stripe_price_plans_select_public ON public.stripe_price_plans;
-- Create policy to allow public read access (anon + authenticated)
CREATE POLICY stripe_price_plans_select_public
  ON public.stripe_price_plans
  FOR SELECT
  TO anon, authenticated
  USING (true);
-- Add comment for documentation
COMMENT ON POLICY stripe_price_plans_select_public ON public.stripe_price_plans 
  IS 'Allow anyone to read pricing plans (needed for pricing page before auth)';
