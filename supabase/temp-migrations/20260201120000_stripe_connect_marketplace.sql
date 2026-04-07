-- Stripe Connect + Marketplace Payments (Accounts v2)

-- Enums
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'stripe_onboarding_status') THEN
    CREATE TYPE public.stripe_onboarding_status AS ENUM (
      'not_started',
      'pending',
      'complete',
      'restricted',
      'rejected'
    );
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'marketplace_payment_status') THEN
    CREATE TYPE public.marketplace_payment_status AS ENUM (
      'requires_payment_method',
      'requires_action',
      'processing',
      'succeeded',
      'canceled',
      'refunded',
      'failed'
    );
  END IF;
END $$;
-- Subscription status on psychologists
ALTER TABLE public.psychologists
  ADD COLUMN IF NOT EXISTS subscription_status TEXT DEFAULT 'none';
-- Connected account mapping (minimal persisted state)
CREATE TABLE IF NOT EXISTS public.psychologist_stripe_connect (
  psychologist_id UUID PRIMARY KEY REFERENCES public.psychologists(id) ON DELETE CASCADE,
  stripe_account_id TEXT UNIQUE NOT NULL,
  onboarding_status public.stripe_onboarding_status NOT NULL DEFAULT 'not_started',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_psychologist_stripe_connect_account_id
  ON public.psychologist_stripe_connect (stripe_account_id);
-- Marketplace payment tracking (checkout + PI audit)
CREATE TABLE IF NOT EXISTS public.marketplace_payment_intents (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  psychologist_id UUID NOT NULL REFERENCES public.psychologists(id) ON DELETE RESTRICT,
  psychologist_client_id UUID REFERENCES public.psychologist_clients(id) ON DELETE SET NULL,
  charge_id UUID REFERENCES public.psychologist_client_charges(id) ON DELETE SET NULL,
  session_id UUID REFERENCES public.clinical_sessions(id) ON DELETE SET NULL,
  stripe_checkout_session_id TEXT UNIQUE,
  stripe_payment_intent_id TEXT UNIQUE,
  stripe_charge_id TEXT,
  stripe_transfer_id TEXT,
  stripe_refund_id TEXT,
  amount_cents INTEGER NOT NULL,
  currency TEXT NOT NULL,
  application_fee_cents INTEGER,
  status public.marketplace_payment_status NOT NULL DEFAULT 'requires_payment_method',
  livemode BOOLEAN NOT NULL DEFAULT false,
  idempotency_key TEXT,
  metadata JSONB,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_marketplace_payment_intents_psychologist
  ON public.marketplace_payment_intents (psychologist_id);
CREATE INDEX IF NOT EXISTS idx_marketplace_payment_intents_charge
  ON public.marketplace_payment_intents (charge_id);
-- Stripe webhook audit / idempotency
CREATE TABLE IF NOT EXISTS public.stripe_webhook_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  stripe_event_id TEXT UNIQUE NOT NULL,
  event_type TEXT NOT NULL,
  stripe_account_id TEXT,
  livemode BOOLEAN NOT NULL DEFAULT false,
  payload JSONB NOT NULL,
  received_at TIMESTAMPTZ DEFAULT NOW(),
  processed_at TIMESTAMPTZ,
  processing_error TEXT
);
-- RLS
ALTER TABLE public.psychologist_stripe_connect ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.marketplace_payment_intents ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.stripe_webhook_events ENABLE ROW LEVEL SECURITY;
-- Psychologists can read their own connect state
DROP POLICY IF EXISTS psychologist_connect_read ON public.psychologist_stripe_connect;
CREATE POLICY psychologist_connect_read
  ON public.psychologist_stripe_connect
  FOR SELECT
  USING (auth.uid() IS NOT NULL AND auth.uid() = psychologist_id);
-- Psychologists can read their own marketplace payments
DROP POLICY IF EXISTS psychologist_payments_read ON public.marketplace_payment_intents;
CREATE POLICY psychologist_payments_read
  ON public.marketplace_payment_intents
  FOR SELECT
  USING (auth.uid() IS NOT NULL AND auth.uid() = psychologist_id);
-- No patient read policy by default; expose via server endpoints if needed.;
