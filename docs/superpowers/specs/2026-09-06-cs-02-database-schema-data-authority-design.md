# CS-02 — Database Schema & Data Authority Foundation Design

## Baseline

- Product: Segeran Jiwa POS Next
- Blueprint: v1.0 FINAL LOCK
- Milestone: CS-02
- Database authority: dedicated Supabase/PostgreSQL project
- Manual Work Budget: LOW

## Authority model

PostgreSQL is authoritative for shared business state. Browser cache and local storage are not business-data authorities. Stock and money are append-only fact ledgers: balances are projections, not directly writable facts. Important writes are idempotent, and a failed command must not leave a success receipt or partial authoritative state.

## Identity and boundaries

`Gudang` and `Gerai` are distinct official locations. Owner and Kasir role references are seeded. RLS is server-side enforcement; UI hiding is not authorization. Generic ledger writer functions remain in the non-exposed `private` schema and are not granted to browser roles in CS-02.

## Data integrity

- completed receipt, audit, inventory, and money facts are immutable;
- reversals are new facts and preserve originals;
- inventory and money balances are security-invoker views derived from ledgers;
- cross-business references are rejected;
- deterministic reference seeds make a fresh foundation reproducible.

## Hosted fix-forward history

The hosted project required four bounded corrections after the six foundation migrations: explicit authenticated read grants, restriction of the provider auto-RLS helper, performance/index hardening plus profile-policy consolidation, and correction of the recorded CS-01 source anchor. History is preserved as ten ordered migrations; already-recorded migrations are not rewritten.

## Delivery boundary

CS-02 adds database source, SQL integration tests, static migration checks, and operational documentation. It intentionally does not add Supabase client runtime code to `src/`. Runtime identity/client integration belongs to a later milestone.
