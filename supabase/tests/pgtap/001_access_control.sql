-- pgTAP: documents baseline **access helpers** for JWT + `user_roles`.
--
-- Template today:
--   * `auth_is_admin()` is hard-wired to the `admin` slug (see migration). Rename the
--     function or replace with `auth_has_app_role(text)` when your product uses another
--     operator role.
--   * `get_user_access_payload` returns empty `permissions` until you enrich the hook /
--     add tables; `subscription` defaults to `{}`.

begin;
select plan(3);

insert into auth.users (id, email)
values
  ('00000000-0000-0000-0000-000000000101', 'admin@example.test'),
  ('00000000-0000-0000-0000-000000000102', 'plain@example.test')
on conflict (id) do nothing;

insert into public.user_roles (user_id, role)
values
  ('00000000-0000-0000-0000-000000000101', 'admin')
on conflict (user_id, role) do nothing;

set local role authenticated;

select set_config(
  'request.jwt.claims',
  '{"sub":"00000000-0000-0000-0000-000000000101","role":"authenticated","app_metadata":{"roles":["admin"]}}',
  true
);

select ok(public.auth_is_admin(), 'template privileged JWT matches auth_is_admin()');

select results_eq(
  $$ select permissions::text, subscription::text from public.get_user_access_payload('00000000-0000-0000-0000-000000000101') $$,
  $$ values ('[]', '{}') $$,
  'hook template: empty permissions[] and default subscription from payload'
);

select set_config(
  'request.jwt.claims',
  '{"sub":"00000000-0000-0000-0000-000000000102","role":"authenticated","app_metadata":{"roles":[]}}',
  true
);

select ok(not public.auth_is_admin(), 'session without privileged role fails auth_is_admin()');

select * from finish();
rollback;
