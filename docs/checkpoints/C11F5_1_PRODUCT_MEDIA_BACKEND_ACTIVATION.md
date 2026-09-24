# C11-F5.1 — Product Media Backend Activation Safe Point

Date: 2026-09-24

## Purpose

C11-F5.1 activates the already-reviewed C11-F5 Product Media contract on the
shared Supabase backend used by the C11 preview so that real-device UAT can
exercise actual upload / replace / remove behavior.

Source baseline:

- branch: `work/c11-visual-convergence`
- responsive/UAT candidate commit: `6212c3ebe1039dcb66a6c7f0e3e8077bbd65acbc`
- source tag: `c11-f7-responsive-visual-matrix-safepoint`
- source migration:
  `supabase/migrations/20260924083000_c11f5_product_media.sql`

Supabase project:

- name: `segeran-jiwa-pos-next`
- project ref: `pkynjaqrxhhnnfuaxoqp`
- region: `ap-southeast-1`
- state at activation: `ACTIVE_HEALTHY`
- Supabase development branches: none

Because there is currently only one Supabase project and no database branch, this
is the same shared backend that earlier C11 preview activation work used.

## Managed backend activation

Managed migration applied successfully:

- remote migration version: `20260924050442`
- remote migration name: `c11f5_product_media`

The migration is additive and installs:

1. optional `public.sale_products.image_path`;
2. the `product-media` Storage bucket;
3. four Storage policies for tenant read and PRODUCT_MANAGE write/update/delete;
4. `public.product_media_capability()`;
5. `public.product_media_read_v1()`;
6. `public.set_sale_product_image(uuid,text,text)`.

No C11-F0B operational-message migration or C11-F0C packaging-reconciliation
migration was promoted as part of this step.

## Storage contract verified

The live bucket now reports:

- bucket: `product-media`;
- public catalog delivery: enabled;
- maximum object size: 2,097,152 bytes (2 MB);
- accepted MIME types: WebP, JPEG, PNG.

Storage mutation policies are scoped to:

- authenticated role;
- active business path in the first folder segment;
- product id in the second folder segment;
- existing product in the active business;
- `PRODUCT_MANAGE` for insert/update/delete.

The public bucket decision is intentional because product catalog images are
presentation media, not private business documents. Mutation authority remains
authenticated and permission bounded.

## RPC security verification

All three Product Media RPCs are SECURITY DEFINER with pinned empty
`search_path`.

Observed execute grants:

- `anon`: denied on all three;
- `authenticated`: allowed on all three;
- `service_role`: no direct execute grant from this migration.

This matches the existing Segeran Jiwa RPC authority pattern: authenticated
entry point plus active-session/business/permission checks inside the function.

A real active Owner session was safely emulated at the database request-claims
boundary for smoke verification:

- `product_media_capability()`: **TRUE**;
- `product_media_read_v1()`: **30 products readable** for that business.

## Writer smoke test

The authoritative writer was exercised inside an explicit rolled-back
transaction using an existing product and a syntactically valid product-media
path.

Observed inside the transaction:

- `set_sale_product_image(...)`: success = **TRUE**;
- replay = **FALSE**.

The transaction was then rolled back.

Post-rollback evidence:

- products with persisted `image_path`: **0**;
- persisted Product Media audit events: **0**.

Therefore the writer, idempotency/audit path, and product-path validation were
executed without leaving test business data behind.

No Storage object was uploaded by this database smoke test.

## Security advisor recheck

Fresh Supabase security advisory review after activation reports:

- RLS-enabled/no-policy findings: **10**, same known protected-table pattern;
- anonymous SECURITY DEFINER warnings: **4**, the known XP Connector V2
  custom-auth surface;
- Product Media RPCs are **not** anonymously executable;
- authenticated SECURITY DEFINER population now includes the three Product Media
  RPCs;
- leaked-password protection warning remains an existing Auth configuration item,
  unrelated to this migration.

No new anonymous Product Media command boundary was introduced.

## Production boundary clarification

This checkpoint does **not** deploy the C11 frontend to the Production site.

However, the shared Supabase backend itself now contains the additive F5 Product
Media capability. Because the project currently has no separate Supabase branch,
it is inaccurate to call the backend completely untouched after this checkpoint.

Backward compatibility is preserved:

- existing products keep `image_path = null`;
- existing checkout/catalog/inventory/finance/shift writers are unchanged;
- a frontend that does not know about Product Media continues operating normally;
- Product Media remains optional presentation data.

Production frontend promotion remains separately blocked behind final C11 UAT
and release approval.

## UAT readiness conclusion

Backend activation status: **PASS**.

The F7 preview can now detect Product Media capability after reload and expose
the real Foto Produk controls to an authorized Owner.

Next stage is C11-F8 Human UAT on real devices. F8 must not be marked PASS until
Owner and Kasir flows are actually exercised and observed.

See also:

- `docs/checkpoints/C11F5_PRODUCT_MEDIA_SAFEPOINT.md`
- `docs/checkpoints/C11F7_RESPONSIVE_VISUAL_MATRIX_SAFEPOINT.md`
- `docs/uat/UAT_C11_F8_OWNER_KASIR_2026-09-24.md`
