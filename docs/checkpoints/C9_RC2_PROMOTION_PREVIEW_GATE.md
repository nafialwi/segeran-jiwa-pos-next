# C9 RC2 Promotion & Preview Gate

Date: 2026-09-22

## Verdict

C9 promotion gate passed for the converged C1-C8 source.

The hosted C2/C3 schema was promoted through managed migrations, the current working source has a successful Cloudflare Pages Preview, and Production application deployment remains disabled.

## Entry evidence

- branch: `work/cs06743-patch3-hardening`
- source HEAD before C9 docs: `38aed0d0f59d8169cb9d5bdf3b583813371f56f0`
- remote branch matched local HEAD
- worktree was clean before promotion
- C8 canonical verification: 96/96 JavaScript + 289/289 Python PASS
- P5C backup health immediately before migration: HEALTHY
- backup SHA-256: `75d9fa5d95d61403d6aa2f1b64f6ba3a9bd87a74b847c8587a25bea06de48ef3`

## Managed migration promotion

Applied in source order:

1. `c2a_product_variant_foundation`
2. `c2b_sale_execution_snapshot`
3. `c2c_read_projection_convergence`
4. `c3b_sales_facts_checkout`

All four are present in Supabase managed migration history in the same order.
Source migration SHA-256 values:

- C2-A: `6208e616eec09008fe890b57ba968132e5a88b6895656ac5330551201400e6fd`
- C2-B: `963af532cb403a14b9ad63b75d01074e3296d4c79f3dd3f2f74b2813d3651840`
- C2-C: `5253b9e9a807ab9fa2c9b6f8a5f717a52dae932afb29fdc6ce54be0d05368a1b`
- C3-B: `f589f5a7a1004ef4fec13d9f7c2cafc30be4e63616d988fb845363cc87c6a247`

## Hosted coherence checks

Post-apply checks confirmed:

- `sale_products`, `product_variants`, `variant_sale_components`, and `sale_item_component_snapshots` exist
- `sales_catalog_v2(uuid)` exists
- both five-argument and six-argument `checkout_sale_v2` authorities exist
- C3-B expected seven added columns are present
- all five C3-B expected constraints are present
- `SALE_DISCOUNT` permission definition is active
- both checkout overloads deny anon execute and allow authenticated execute
- public command functions retain pinned empty `search_path` and authority checks

Repository-hosted SQL validation after promotion:

- C2-A integration SQL: PASS
- C2-B integration SQL: PASS with rollback
- C2-C integration SQL: PASS with rollback
- C3-B exact fixture was not re-submitted through the connector because the connector blocked that large auth-fixture payload before database execution; C8 already proved the identical C3-B payload transactionally, and C9 separately verified its promoted columns, constraints, RPC signatures, grants, and authority boundary.

## Security recheck

Fresh post-DDL advisors remain consistent with the known security model:

- RLS-without-policy INFO population remains 10
- anon SECURITY DEFINER warnings remain 4 and are the previously reviewed XP Connector V2 custom-auth surface
- authenticated SECURITY DEFINER warnings are now 63 because the promoted authenticated command/read surfaces are present
- new checkout/read RPCs are not executable by anon
- no new anonymous application command exposure was introduced

The additional authenticated findings are expected command boundaries and remain subject to the same authority checks used by the converged source.

## Preview smoke

Cloudflare Pages check for source commit `38aed0d0` completed successfully.

Preview URL:

`https://3a8c1645.segeran-jiwa-pos-next.pages.dev`

Chrome 153 headless smoke at 390x844 confirmed:

- page load succeeds
- title is `Segeran Jiwa POS Next`
- JavaScript advances from session verification to the login screen
- username/password/device-kind controls render
- no Chrome stderr was emitted during the smoke

This is unauthenticated smoke only. Authenticated acceptance remains C10 Human UAT.

## Release rule

RC1 remains immutable.

C9 prepares RC2 from the current converged source. Production automatic deployment stays disabled.

Next phase after RC2 tag and Preview confirmation:

**C10 — Batched Human UAT**

Human UAT remains required before final post-UAT regression and cutover readiness can become PASS.

## Immutable RC2 lock

- candidate tag: `uat-rc-20260922-2`
- candidate commit: `d4776b64550550c17f484eb68132185bcdfb8896`
- final RC2 Preview: `https://3da4be58.segeran-jiwa-pos-next.pages.dev`
- GitHub canonical verify: PASS
- Cloudflare Pages deployment: PASS
- Chrome 153 390x844 login smoke on final RC2 Preview: PASS
- Production application deployment: unchanged / disabled

C10 Human UAT must use this RC2 Preview.
