# C11-F5 — Product Media & Catalog Completion Safe Point

Date: 2026-09-24

## Purpose

C11-F5 closes the remaining Product Media source gap after report convergence.

The product domain previously had no first-class presentation image. Product
cards in Jual and Product Operations always used the generic product icon even
when a real product photo would make daily cashier work faster.

This checkpoint adds optional product presentation media without changing stock,
sale, inventory, finance, shift, BOM, refund, correction, or historical sale
truth.

Baseline:

- branch: `work/c11-visual-convergence`
- baseline commit: `939c4c00de0d765f41d287e7294906d42dbd5e08`
- previous tag: `c11-f4.2-report-information-architecture-safepoint`
- Production: untouched

## Product media model

A new optional `sale_products.image_path` stores only the current presentation
image pointer.

The actual image object lives in a dedicated Supabase Storage bucket:

- bucket: `product-media`
- public delivery: yes, because these are catalog presentation images, not
  confidential documents
- maximum stored object size: 2 MB
- accepted object MIME types: WebP, JPEG, PNG

Object paths are product-scoped:

`<business_uuid>/<product_uuid>/<random_uuid>.<ext>`

The database constraint verifies that the first two path segments match the
product business and product id.

Historical transactions remain snapshot-based and are not rewritten when an
image changes.

## Write authority and storage safety

Media mutation requires existing `PRODUCT_MANAGE` authority.

Storage INSERT/UPDATE/DELETE policies are tenant-path bounded and require the
target product to belong to that business.

The database pointer is changed only through:

- `set_sale_product_image(product_id, image_path, idempotency_key)`

That RPC is:

- authenticated only;
- PRODUCT_MANAGE bounded;
- tenant/product bounded;
- path validated;
- idempotency bounded through the canonical operation receipt mechanism;
- audit-event recorded.

No direct frontend write grant is added to `sale_products`.

Audit events distinguish image add, replace, and remove.

## Upload / replace / remove flow

The browser accepts JPG, PNG, or WebP source files up to 12 MB.

Before upload the image is processed locally:

- longest edge is reduced to at most 1200 px;
- WebP is preferred;
- quality is stepped down when required;
- JPEG is the fallback encoder;
- final object must be at most 2 MB.

Replace flow is fail-safe:

1. compress the new image;
2. upload it under a new immutable random object path;
3. update the authoritative product image pointer;
4. if pointer update fails, remove the newly uploaded object;
5. after a successful pointer switch, old-object cleanup is best effort.

Remove flow clears the authoritative database pointer first, then cleans the old
storage object best effort. A storage cleanup failure therefore cannot leave the
catalog pointing to a deleted object.

## Product Master UI

Existing products now have a Foto Produk section in Product Master.

Authorized users can:

- see the current product image preview;
- choose a JPG/PNG/WebP image;
- replace the current image;
- remove the current image.

A new product must first be saved so it has an authoritative product id before
media can be uploaded.

If the media migration is not installed, the Product Master editor remains
usable and the media section reports that photos are not active on that backend.

Media capability failure is isolated from Product Master capability. A transient
or unavailable media backend does not disable ordinary product editing.

## Jual and Product Operations

Jual loads product media as non-blocking presentation support after the
authoritative sellable catalog is already available.

Therefore:

- active shift + catalog remain the first-paint authority;
- a slow/missing media RPC does not block selling;
- cards keep the canonical product placeholder if no image exists or an image
  fails to load;
- existing 2/3/4-column density behavior is preserved.

Product Operations also reads media separately and non-blockingly.

When available, the image appears in:

- Product Operations list thumbnail;
- selected-product hero;
- Jual product card.

No image is required for a product to remain sellable.

## Migration status

Migration source prepared:

`supabase/migrations/20260924083000_c11f5_product_media.sql`

It is committed as source for controlled schema/storage application later.

It has **NOT** been applied to Production in this checkpoint.

The frontend uses `product_media_capability` and fail-closed optional reads, so
an older backend continues to show placeholders rather than a broken media UI.

## Verification

Focused C11-F5 tests:

- Product Media: **8/8 PASS**
- Product Media + migration source-control guard: **14/14 PASS**

Canonical verification after implementation:

- JavaScript: **96/96 PASS**
- Python: **420/420 PASS**
- repository guard: **PASS**
- Prettier: **PASS**
- ESLint: **PASS**
- TypeScript: **PASS**
- production build: **PASS**
- `git diff --check`: **PASS**

The existing Vite `INEFFECTIVE_DYNAMIC_IMPORT` advisory for
`src/lib/supabase.ts` remains unchanged.

## Safety conclusion

C11-F5 is a source safe point.

Product media is optional presentation data with a narrow authority boundary.
Failure or absence of media cannot change sale, stock, money, shift, purchase,
or historical transaction facts.

## Remaining C11 work

Next planned stage:

1. C11-F6 — Daily Interaction Cleanup and input-mode sweep;
2. C11-F7 — full responsive matrix;
3. C11-F8 — Owner/Kasir real-device UAT;
4. C11-F9 — final regression;
5. C11 Final Lock / RC5 only after blockers are zero.
