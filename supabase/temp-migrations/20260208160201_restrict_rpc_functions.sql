-- TM-003: Restrict RPC Decryption Functions
-- Purpose: Reduce attack surface by restricting access to decryption functions

-- 1. Create audit logging wrapper
CREATE OR REPLACE FUNCTION public.decrypt_token_base64_secure(
  encrypted_token_base64 TEXT,
  encryption_key TEXT,
  p_context TEXT DEFAULT 'unknown'
)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  decrypted TEXT;
  v_user_id UUID;
BEGIN
  v_user_id := auth.uid();
  
  -- Perform decryption using the original function
  -- We assume public.decrypt_token_base64 still exists and is granted to service_role
  SELECT public.decrypt_token_base64(encrypted_token_base64, encryption_key) INTO decrypted;
  
  -- Log successful decryption
  INSERT INTO public.encryption_audit_log (
    operation,
    success,
    caller_user_id,
    context
  ) VALUES (
    'decrypt',
    true,
    v_user_id,
    p_context
  );
  
  RETURN decrypted;
EXCEPTION WHEN OTHERS THEN
  -- Log failed decryption
  INSERT INTO public.encryption_audit_log (
    operation,
    success,
    error_message,
    caller_user_id,
    context
  ) VALUES (
    'decrypt',
    false,
    SQLERRM,
    v_user_id,
    p_context
  );
  RAISE;
END;
$$;
-- 2. Restrict original functions to service_role only
-- First, revoke from public and authenticated
REVOKE EXECUTE ON FUNCTION public.decrypt_token_base64(TEXT, TEXT) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.decrypt_token_base64(TEXT, TEXT) FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.encrypt_token_base64(TEXT, TEXT) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.encrypt_token_base64(TEXT, TEXT) FROM authenticated;
-- Ensure service_role has access (usually does by default, but being explicit)
GRANT EXECUTE ON FUNCTION public.decrypt_token_base64(TEXT, TEXT) TO service_role;
GRANT EXECUTE ON FUNCTION public.encrypt_token_base64(TEXT, TEXT) TO service_role;
-- Grant access to the new secure wrapper to service_role only
REVOKE EXECUTE ON FUNCTION public.decrypt_token_base64_secure(TEXT, TEXT, TEXT) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.decrypt_token_base64_secure(TEXT, TEXT, TEXT) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.decrypt_token_base64_secure(TEXT, TEXT, TEXT) TO service_role;
