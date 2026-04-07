-- Add related_evolution_id to clinical_notes
ALTER TABLE "public"."clinical_notes"
ADD COLUMN "related_evolution_id" uuid NULL;
-- Add foreign key constraint
ALTER TABLE "public"."clinical_notes"
ADD CONSTRAINT "clinical_notes_related_evolution_id_fkey"
FOREIGN KEY ("related_evolution_id")
REFERENCES "public"."clinical_notes" ("id")
ON DELETE SET NULL;
