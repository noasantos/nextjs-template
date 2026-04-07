-- Link psychologist_services to psychological_services_catalog (idempotent)
alter table public.psychologist_services
  add column if not exists catalog_id uuid;
do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'psychologist_services_catalog_id_fkey'
  ) then
    alter table public.psychologist_services
      add constraint psychologist_services_catalog_id_fkey
      foreign key (catalog_id) references public.psychological_services_catalog(id) on delete set null;
  end if;
end $$;
-- Backfill catalog_id by name (case-insensitive)
update public.psychologist_services ps
set catalog_id = c.id
from public.psychological_services_catalog c
where ps.catalog_id is null
  and lower(trim(ps.name)) = lower(trim(c.name));
-- Normalize stored name to the catalog name when linked
update public.psychologist_services ps
set name = c.name
from public.psychological_services_catalog c
where ps.catalog_id = c.id
  and (ps.name is null or ps.name <> c.name);
create index if not exists psychologist_services_catalog_id_idx
  on public.psychologist_services(catalog_id);
