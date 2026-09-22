# C8 Full Cross-domain Regression — SAFEPOINT

Date: 2026-09-22

Branch: work/cs06743-patch3-hardening

Regression target commit:

41f198013a70ce0ecc7216df43d5a9e904f92c4e

## Verdict

PASS_SAFEPOINT

C8 re-proves the converged C1-C7 source and the active RC1 backend authority without redesigning or
rewriting any business engine.

C8 performs no persistent database migration and no application deployment.

RC1 remains immutable:

uat-rc-20260921-1 -> e844f9b9ad07ca240e1ba4f72a39c6c7aefbb489

Production automatic deployment remains disabled.

Structured evidence:

docs/checkpoints/C8_REGRESSION_EVIDENCE.json

## C2/C3 promotion state

C2/C3 remain intentionally source-controlled until the RC2 promotion gate.

Fresh hosted checks confirmed that these RC2 tables are still absent from the active hosted schema:

- public.sale_products;
- public.product_variants;
- public.variant_sale_components.

This is expected before RC2 and proves C8 did not accidentally promote the new schema.

## C2/C3 real rehearsal continuity

C2-A, C2-B, C2-C and C3-B had already been executed against hosted PostgreSQL inside explicit
transactions and rolled back during their own checkpoints.

C8 verified that the exact four migration files and four SQL regression files used by that
rehearsal are byte-for-byte unchanged since the C3-B safe point f0709ea.

No migration or SQL-test delta exists under supabase/migrations or supabase/tests between the C3-B
safe point and the C8 regression target.

Therefore the prior real transactional rehearsal still applies to the exact SQL payload currently
being promoted toward RC2.

Recorded SHA-256 values are stored in C8_REGRESSION_EVIDENCE.json.

## Fresh hosted RC1 authority probe

C8 executed a fresh read-only hosted database probe.

Result:

31/31 PASS

The probe verified the active RC1 authorities required by the converged frontend:

- Segeran Jiwa business and locations;
- operation receipts / idempotency infrastructure;
- shifts and handovers;
- purchase orders;
- production batches;
- refund facts;
- correction facts;
- Transaction History RPC;
- Reports RPC;
- shift open / close / reconciliation RPCs;
- Purchase order / GRN / Direct Buy RPCs;
- Production create / post RPCs;
- Refund RPC;
- Correction RPC;
- current authority RPC;
- canonical private inventory writer;
- canonical private money writer;
- private idempotency gate;
- Shift RLS;
- Refund fact trigger;
- Correction immutable trigger.

The same probe confirmed that the C2 schema has not been persistently applied.

## Writer call-chain verification

An initial shallow probe searched for the canonical inventory writer directly inside public wrapper
functions. It returned false for three cases: Production replay/idempotency, Goods Receipt inventory
posting, and Direct Buy inventory posting.

These were probe-model assumptions, not product failures.

C8 stopped and traced the active function definitions before classifying the result.

The corrected read-only call-chain probe passed:

7/7 PASS

Production uses authority checks, row locking, POSTED replay semantics, shortage fail-closed checks
and private.record_inventory_movement.

Goods Receipt creation is idempotent through private.lock_operation and
private.record_operation_success. Inventory is posted by post_goods_receipt through the canonical
inventory writer.

Direct Buy delegates purchase_create_order -> purchase_create_goods_receipt -> post_goods_receipt
and does not implement a second inventory writer.

## Cross-domain source regression

Canonical verification on the complete C1-C7 source passed:

- repository guard: PASS;
- formatting: PASS;
- lint: PASS;
- TypeScript: PASS;
- JavaScript: 96/96 PASS;
- Python: 289/289 PASS;
- production build: PASS;
- git diff check: PASS.

The suite covers sale execution, snapshots/readers, Finance, Shift, Purchase, Production, inventory
controls, History, Refund, Correction, Reports, permissions, device authority, offline fail-closed
boundaries, backup/cutover helpers and previous UAT blocker regressions.

## Sale -> stock -> money -> history continuity

C8 uses two independent layers of evidence:

1. current canonical source tests pass for C2-A/C2-B/C2-C/C3-A/C3-B;
2. the SQL payload used by the earlier real C3-B transactional hosted rehearsal is byte-identical
   to the current payload.

This preserves the proof for variant checkout identity, sale-time component snapshots, one inventory
engine, one money engine, stock-low fail-closed behavior, idempotency/replay, full-discount stock
consumption, line-note facts, tender/change facts, V2 History projection, V2 report product identity
and Refund/Correction compatibility with the original movement snapshot.

## Purchase / Production / inventory continuity

Fresh hosted RC1 probes verified the active authority functions, while canonical source tests
re-proved:

- PO does not directly write stock;
- GRN creation does not directly write stock;
- GRN posting uses the canonical inventory engine;
- Direct Buy delegates through PO/GRN/post;
- Production uses version-bound BOM facts;
- Production posts one canonical inventory movement;
- Production shortage fails closed;
- Production replay does not duplicate stock;
- inventory request / transfer / count / adjustment boundaries remain permission-gated;
- packaging/cup remains ordinary inventory evidence, not a second stock authority.

## Refund / Correction continuity

Fresh hosted probes confirmed Refund and Correction facts/RPCs and immutability guards remain
present.

Source regression re-proved that original Sale facts are not rewritten, Refund and Correction
remain distinct, both use canonical inventory/money engines, second-attempt/idempotency guards
remain, unsupported Correction paths fail closed, and QRIS is not silently cancelled through an
automatic provider workflow.

## Shift / reconciliation continuity

Fresh hosted probes confirmed Shift table, Shift RLS, open RPC, close RPC, reconciliation RPC and
Handover authority.

Source regression re-proved expected/actual/variance, cash integration, live running cash, packaging
evidence and reconciliation presentation contracts.

## Permission / device / offline boundaries

C8 canonical tests re-proved permission, authority, device and AppShell contracts.

Business mutations remain online-only. No offline mutation queue was introduced and ambiguous
network failure is not silently replayed.

## Fresh security gate

C8 refreshed Supabase security advisors and catalog evidence.

Catalog result:

- public RLS tables: 65;
- RLS enabled with no policy: 10;
- direct grants from those no-policy tables to anon or authenticated: 0;
- public authenticated SECURITY DEFINER functions: 60;
- public authenticated SECURITY DEFINER functions also executable by anon: 0;
- authenticated public SECURITY DEFINER functions missing fixed search path: 0;
- anon has USAGE on private schema: false.

The first broad catalog query mixed exposed public RPCs with private-schema helpers. C8 checked
schema USAGE before classification. Restricting the exposed population to public reproduces the P5D
60 / 0 / 0 classification.

Fresh advisors observed at 2026-09-22T11:50:12.942Z show the same already-classified state:

- 10 RLS-without-policy INFO findings;
- 4 anon SECURITY DEFINER warnings for XP Connector V2 custom-auth RPCs;
- 60 authenticated SECURITY DEFINER warnings;
- leaked-password protection warning.

No new security drift was identified.

The 10 no-policy tables have zero direct grants to anon/authenticated. The four Connector V2 anon
warnings remain the previously reviewed custom-auth surface. Authenticated SECURITY DEFINER findings
remain CLEAR_OR_ACCEPTED. Leaked-password protection remains the accepted Free-plan platform
limitation.

## Backup / restore recheck

C8 re-ran the repository backup-health validator using the locked P5C bundle and its actual retained
Windows copy outside the WSL project filesystem.

Result:

BACKUP_HEALTH=HEALTHY

Backup SHA-256:

75d9fa5d95d61403d6aa2f1b64f6ba3a9bd87a74b847c8587a25bea06de48ef3

The locked restore evidence remains PASS.

A broad Windows retained-copy filesystem scan timed out and was intentionally abandoned. The exact
retained path was recovered from previous P5C job metadata, after which the official validator
passed. The timeout was therefore a discarded discovery method, not a backup-health failure.

## Cutover gate

C8 re-ran cutover readiness.

Expected result:

CUTOVER_READY=NO

Current blockers are exactly:

1. Official UAT has not PASSed;
2. final post-UAT regression has not PASSed.

Production automatic deployment remains DISABLED.

C8 is not final post-UAT regression and does not change final_regression_status.

## Database / deployment impact

C8 performed read-only hosted catalog/function/security probes, local source/test/build verification,
local backup bundle validation and cutover-readiness evaluation.

C8 performed no persistent migration, Production data mutation, C2/C3 persistent schema apply,
Cloudflare deployment, RC tag creation or Production deployment.

## Error containment

C8 used bounded gates.

- A broad retained-copy filesystem search timed out. No state changed; the exact path was recovered
  from P5C job metadata.
- The first writer probe was too shallow for Production and Purchase wrappers. Active definitions
  were traced read-only and the corrected probe passed 7/7.
- A broad SECURITY DEFINER query mixed public RPCs with private helpers. Schema USAGE proved anon
  cannot call private helpers; public exposed classification matches P5D.

These were evidence-analysis corrections, not runtime regressions.

## C8 exit condition

C8 is complete because C1-C7 source passes canonical verification, C2/C3 promotion payload is
identical to the real transactional rehearsal payload, active RC1 authorities remain present,
single-writer chains remain intact, security has no new drift, backup remains HEALTHY, cutover
remains correctly fail-closed, RC1 remains immutable and Production remains untouched.

## Next safe phase

C9 — RC2 Promotion & Preview Gate.

C9 is the first phase allowed to prepare promotion of the source-controlled C2/C3 database changes
and create a new RC2 Preview.

Because persistent C2/C3 migration changes the hosted schema, C9 must remain controlled:

1. re-confirm clean Git and immutable RC1;
2. re-confirm backup gate immediately before schema promotion;
3. verify exact managed migration order;
4. execute the approved managed migration path with explicit post-apply checks;
5. prove the C2/C3 schema and V2 checkout authority are present;
6. create/tag the RC2 candidate only after migration/source coherence is proven;
7. create a new Cloudflare Preview;
8. run browser smoke against RC2;
9. keep Production application deployment disabled;
10. proceed to C10 batched Human UAT only after RC2 smoke passes.

Do not reuse or mutate RC1.
