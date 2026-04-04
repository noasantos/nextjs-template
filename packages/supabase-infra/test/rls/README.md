Add table-specific `*.rls.test.ts` files here when the first protected public
table exists. The generated database types are currently empty, so the initial
rollout wires the suite and helpers without inventing fake RLS targets.
