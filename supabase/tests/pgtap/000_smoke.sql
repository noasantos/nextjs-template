begin;
select plan(2);

select ok(
  exists(select 1 from information_schema.schemata where schema_name = 'public'),
  'public schema exists'
);

select ok(
  exists(select 1 from information_schema.schemata where schema_name = 'auth'),
  'auth schema exists'
);

select * from finish();
rollback;
