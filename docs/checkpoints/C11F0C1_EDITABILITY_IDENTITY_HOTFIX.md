# C11-F0C.1 — Editability & Identity Browser Hotfix

Date: 2026-09-23

## Why this checkpoint exists

Two practical blockers were confirmed during preview use:

1. Product Master editing existed in source but its F0A backend capability had not yet been activated on the shared Supabase project used by the preview.
2. Owner > Pengguna could show the raw transport message SJ_IDENTITY_ADMIN_FAILED because browser Edge Function preflight was not explicitly handled.

This checkpoint closes those blockers without changing checkout, inventory, finance, or shift truth.

## Product edit activation

The C11-F0A Product Master authority is now applied on the shared Supabase project. Owner authority can now pass product_master_capability() and use the existing editor under Menu > Produk & Resep.

The server remains permission bounded by PRODUCT_MANAGE, idempotency receipts, audit events, and historical sale snapshots.

### FINISHED_GOOD safety

A direct/preproduced variant requires a system FINISHED_GOOD component for checkout V2. The canonical F0A source derives that component server-side. A smoke test was executed inside a rolled-back transaction against an existing DIRECT_STOCK variant and confirmed exactly one matching FINISHED_GOOD line after save.

Therefore editing a price, variant, or packaging line cannot silently remove the checkout-required stock component.

## Owner user administration browser fix

identity-admin and device-admin now:

- answer browser OPTIONS preflight with explicit CORS headers;
- return the same CORS headers on JSON responses;
- use verify_jwt = false at the gateway so OPTIONS is not rejected first;
- still require a real bearer token in function code;
- validate the token using auth.getUser;
- validate the active Segeran Jiwa session;
- require Owner authority for every administration action.

So disabling gateway JWT verification does not make the POST operation public. The function itself remains fail-closed.

Live smoke checks confirmed:

- unauthenticated OPTIONS => HTTP 200 with expected CORS headers;
- unauthenticated POST => HTTP 401 from the function;
- identity/device Edge Functions are deployed as version 3.

The Owner Users frontend also converts Edge Function transport failures to a human-readable Indonesian message instead of displaying internal SJ_IDENTITY_ADMIN_FAILED / SJ_DEVICE_ADMIN_FAILED codes.

## Deployment status

This checkpoint changes the shared backend used by C11 preview:

- F0A Product Master database authority: APPLIED;
- Product variant source-sync/FINISHED_GOOD guard: APPLIED;
- identity-admin: version 3 deployed;
- device-admin: version 3 deployed.

Frontend Production remains blocked. No C11 frontend is promoted to the production site by this checkpoint.

C11-F0B operational-message and C11-F0C shift-packaging migrations remain source-prepared unless separately promoted.

## Verification

Canonical verification after the source/browser fix:

- JavaScript: **96/96 PASS**;
- Python: **363/363 PASS**;
- repository guard: PASS;
- Prettier: PASS;
- ESLint: PASS;
- TypeScript: PASS;
- production build: PASS;
- git diff-check: PASS.

## Next

Continue C11-F0D — Sales Daily-Use Completion, then C11-F0E and C11-F final responsive/regression QA. The complete operator/owner user guide is intentionally deferred until those flows are stable so the guide does not document temporary UI.
