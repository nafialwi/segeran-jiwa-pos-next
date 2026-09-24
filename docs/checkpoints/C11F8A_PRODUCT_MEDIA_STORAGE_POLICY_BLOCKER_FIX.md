# C11-F8A — Product Media Storage Policy Blocker Fix

Date: 2026-09-24

## Human UAT finding

During the first real-device Product Media upload attempt on Android, Product
Master surfaced:

`permission denied for function has_permission`

The browser-side Product Master and Product Media capability were already active.
The failure occurred only when the Storage API attempted to insert the uploaded
object into `storage.objects`.

Fresh Supabase logs at 05:29–05:30 UTC confirmed the exact failing command:

- application: Supabase Storage API;
- command: INSERT into `storage.objects`;
- SQLSTATE: 42501;
- error: `permission denied for function has_permission`.

Severity at discovery: **P1 for Product Media UAT**. Existing sales/product
operation remained usable, but the new photo-upload workflow could not complete.

## Root cause

The original C11-F5 Storage mutation policies called:

`private.has_permission(..., 'PRODUCT_MANAGE')`

directly inside `storage.objects` RLS policy expressions.

That private helper intentionally does not grant EXECUTE to ordinary authenticated
API roles. This is correct for application security, but it means a Storage API
RLS policy must not invoke the private helper directly.

The earlier database smoke test exercised the Product Media pointer RPC, not a
real `storage.objects` INSERT, so it correctly verified the RPC while missing
this Storage-specific execution context.

## Fix

Added migration source:

`supabase/migrations/20260924124500_c11f5a_product_media_storage_policy_fix.sql`

The three mutation policies now obtain the already-authoritative permission list
through `public.get_my_authority()` and require:

`(public.get_my_authority() -> 'permissions') ? 'PRODUCT_MANAGE'`

This preserves the same business/permission boundary while avoiding direct
execution of a private helper from the Storage policy.

Tenant and product path checks remain unchanged:

- bucket must be `product-media`;
- path segment 1 must equal active business id;
- path segment 2 must equal an existing product in that business;
- policy role remains `authenticated`;
- no anon/public write policy was added.

## Live backend repair

Managed migration applied successfully to project
`pkynjaqrxhhnnfuaxoqp`:

- remote version: `20260924053235`;
- name: `c11f5a_product_media_storage_policy_fix`.

## Storage RLS smoke after repair

A real RLS INSERT into `storage.objects` was executed using an active Owner
request-claims context and a valid business/product media path, inside an explicit
transaction that was rolled back.

Observed:

- Storage RLS insert: **PASS**;
- rows inserted inside transaction: **1**;
- transaction: rolled back;
- persisted Product Media storage objects after smoke: **0**.

This specifically exercises the same RLS layer that failed during Android UAT.

## Source regression

New source regression verifies:

- repair migration exists;
- Storage policies no longer call `private.has_permission` directly;
- `PRODUCT_MANAGE` is read from public authority projection;
- tenant/product path bounds remain present;
- mutation policies remain authenticated-only;
- original Product Media RPC authority contract remains unchanged.

## UAT status

Backend blocker repair: **PASS**.

Human Product Media upload is **PENDING RETEST** on the same Android UAT flow.

Do not mark C11-F8 PASS until upload / replace / remove is successfully observed
on-device and the remaining Owner/Kasir matrix is completed.

## Verification

Focused Product Media + migration registry regression after the repair:

- **19/19 PASS**

Canonical source verification:

- JavaScript: **96/96 PASS**
- Python: **443/443 PASS**
- repository guard: **PASS**
- Prettier: **PASS**
- ESLint: **PASS**
- TypeScript: **PASS**
- production build: **PASS**
- `git diff --check`: **PASS**

The existing Vite `INEFFECTIVE_DYNAMIC_IMPORT` advisory for
`src/lib/supabase.ts` remains unchanged and was not introduced by this repair.
