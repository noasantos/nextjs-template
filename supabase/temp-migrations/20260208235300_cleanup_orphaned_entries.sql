-- ============================================================================
-- Migration: Cleanup orphaned daily consolidation entries
-- 
-- Removes entries that have no corresponding paid charges for that date.
-- ============================================================================

-- Delete daily consolidation entries where there are no paid charges for that date
DELETE FROM psychologist_financial_entries e
WHERE e.type = 'income'
  AND e.description LIKE 'Serviços Prestados%'
  AND NOT EXISTS (
    SELECT 1 
    FROM psychologist_client_charges c
    JOIN clinical_sessions s ON s.id = c.session_id
    WHERE c.psychologist_id = e.psychologist_id
      AND c.payment_status = 'paid'
      AND s.start_time::date = e.date_time::date
  );
