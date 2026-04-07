-- Link existing files in storage bucket activity-pdfs to clinical activities.
-- This migration fills clinical_activities_catalog.pdf_path based on file names.
WITH pdf_objects AS (
  SELECT
    o.name AS file_path,
    trim(
      both '-'
      FROM regexp_replace(
        regexp_replace(
          regexp_replace(
            lower(translate(o.name, 'áàâãäéèêëíìîïóòôõöúùûüç', 'aaaaaeeeeiiiiooooouuuuc')),
            '-fluri[.]pdf$',
            '',
            'g'
          ),
          '[.]pdf$',
          '',
          'g'
        ),
        '[^a-z0-9]+',
        '-',
        'g'
      )
    ) AS normalized_slug
  FROM storage.objects o
  WHERE o.bucket_id = 'activity-pdfs'
),
mapped_pdfs AS (
  SELECT
    file_path,
    CASE
      WHEN normalized_slug = 'matrix-de-prioridade' THEN 'matriz-de-prioridades'
      WHEN normalized_slug = 'registro-de-pensamento-distorcido' THEN 'registro-pensamentos-distorcidos'
      ELSE normalized_slug
    END AS activity_code
  FROM pdf_objects
)
UPDATE public.clinical_activities_catalog c
SET
  pdf_path = m.file_path,
  updated_at = NOW()
FROM mapped_pdfs m
WHERE c.code = m.activity_code
  AND (c.pdf_path IS NULL OR c.pdf_path = '');
