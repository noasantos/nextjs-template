alter table public.psychologist_profiles
add column if not exists accepting_new_patients boolean not null default false;
