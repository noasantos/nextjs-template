-- migration-created-via: pnpm supabase:migration:new
-- created-at-utc: 2026-02-22T10:58:06Z

-- =====================================================
-- FIX: Existing users with active subscription but missing onboarding steps
-- =====================================================
-- PROBLEM: Users created before the new onboarding logic have subscription active
-- but identity_step_completed and professional_step_completed are FALSE.
-- This causes essential_complete = FALSE, blocking app access.
--
-- SOLUTION: Mark identity and professional as complete for users who have
-- subscription active AND already have draft_data (meaning they completed onboarding)

-- =====================================================
-- 1. Update users with active subscription and existing draft data
-- =====================================================

UPDATE psychologist_onboarding_state pos
SET 
  identity_step_completed = TRUE,
  professional_step_completed = TRUE,
  readiness_step_completed = CASE 
    WHEN readiness_step_completed = TRUE THEN TRUE 
    ELSE FALSE  -- Keep existing or default to false
  END,
  updated_at = NOW()
FROM user_psychologists up
WHERE pos.psychologist_id = up.id
  AND up.subscription_status IN ('active', 'trialing')
  AND pos.draft_data IS NOT NULL
  AND (pos.identity_step_completed = FALSE OR pos.professional_step_completed = FALSE);
-- =====================================================
-- 2. For users with subscription but NO draft data (signup but no onboarding yet)
-- Keep them with identity/professional as FALSE - they need to complete onboarding
-- =====================================================

-- =====================================================
-- 3. Recalculate progress for all affected users
-- =====================================================

DO $$
DECLARE
  r RECORD;
BEGIN
  FOR r IN 
    SELECT psychologist_id 
    FROM psychologist_onboarding_state 
    WHERE updated_at > NOW() - INTERVAL '1 minute'
  LOOP
    PERFORM public.calculate_onboarding_progress(r.psychologist_id);
  END LOOP;
END $$;
-- =====================================================
-- 4. Verify results
-- =====================================================

-- Show summary of affected users
SELECT 
  COUNT(*) as total_users,
  COUNT(*) FILTER (WHERE essential_complete = TRUE) as with_essential_complete,
  COUNT(*) FILTER (WHERE fully_complete = TRUE) as with_fully_complete,
  COUNT(*) FILTER (WHERE subscription_status IN ('active', 'trialing') AND essential_complete = FALSE) as active_but_no_essential
FROM psychologist_onboarding_summary;
