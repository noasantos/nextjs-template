-- Create calendar_holidays table
CREATE TABLE IF NOT EXISTS public.calendar_holidays (
    id           bigint generated always as identity primary key,
    year         integer      NOT NULL,
    state        text         NULL, -- UF, e.g. 'RS'
    city         text         NULL, -- e.g. 'Porto Alegre'
    date         date         NOT NULL,
    name         text         NOT NULL,
    type         text         NULL, -- national, state, municipal
    description  text         NULL,
    source       text         NOT NULL DEFAULT 'feriados.dev',
    created_at   timestamptz  NOT NULL DEFAULT now(),
    updated_at   timestamptz  NOT NULL DEFAULT now()
);
-- Add unique constraint to avoid duplicates
ALTER TABLE public.calendar_holidays
ADD CONSTRAINT calendar_holidays_year_state_city_date_unique
UNIQUE (year, state, city, date);
-- Index for querying
CREATE INDEX IF NOT EXISTS idx_calendar_holidays_year_state_city_date
  ON public.calendar_holidays (year, state, city, date);
-- Enable RLS
ALTER TABLE public.calendar_holidays ENABLE ROW LEVEL SECURITY;
-- RLS Policies
CREATE POLICY "Allow authenticated users to read holidays"
ON public.calendar_holidays
FOR SELECT
TO authenticated
USING (true);
-- Table comment
COMMENT ON TABLE public.calendar_holidays IS 'Stores Brazilian holidays (national, state, municipal) cached from feriados.dev.';
