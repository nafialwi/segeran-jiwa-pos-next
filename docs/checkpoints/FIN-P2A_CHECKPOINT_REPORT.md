# FIN-P2A CHECKPOINT REPORT

Project: segeran-jiwa-pos-next  
Checkpoint: FIN-P2A Shift Funding Bridge  
Date: 2026-09-20  
Branch: work/cs06743-patch3-hardening  
Planning Safepoint: 21cda5830f99f85172ab68ed419878ebfb6e4f7d  
Technical Source Commit: 97fb82afa34f09936955df2bf65a3c91d9b2be62  
Status: LOCKED_REMOTE

## Purpose

FIN-P2A closes the finance/shift integrity gap where a positive opening balance could previously appear on a shift without an explicit money source.

The locked business authority requires:

- no money without an origin and destination;
- opening cash source selection;
- Kas Utama -> Kas Shift is an internal transfer, not income/expense;
- Shift is operational context, not a second money ledger.

## Implemented scope

Migration:

- `20260920150000_fin_p2a_shift_funding_bridge.sql`

Shift provenance fields:

- `opening_source_type`
- `opening_source_ref`
- `opening_money_movement_id`

Legacy RPC hardening:

- `cs05_open_my_shift(...)` still accepts zero opening balance.
- positive opening through the legacy RPC fails closed with `FINANCE_OPENING_SOURCE_REQUIRED`.
- zero opening records provenance `ZERO`.

New RPC:

- `finance_open_shift_from_main_cash(location, opening, config, idempotency_key)`

The funded-open command:

1. validates current shift authority;
2. validates business/location;
3. requires positive opening amount;
4. resolves active `KAS_UTAMA` and `KAS_SHIFT`;
5. checks canonical Kas Utama balance;
6. takes an outer idempotency lock;
7. creates the Shift Aktual;
8. creates exactly one canonical `TRANSFER` from Kas Utama to Kas Shift;
9. records shift funding provenance;
10. records operation success;
11. returns the same shift on retry with the same operation key.

Opening balance and funding provenance are immutable after creation.

Frontend:

- positive opening uses `finance_open_shift_from_main_cash`;
- zero opening continues through the zero-balance legacy path;
- Shift UI labels the positive opening source as `Kas Utama`;
- global finance balances remain hidden from Kasir.

## TDD evidence

RED:

- FIN-P2A source test failed because the migration did not exist.
- frontend source test failed because the funded-open RPC was not used.

GREEN:

- focused FIN-P2A source tests PASS;
- migration registry tests PASS;
- full canonical verification PASS.

## Canonical verification

Final command after hosted apply: `npm run verify`  
Result: CLEAR

- JS: 14 files, 73/73 tests PASS
- Python: 118/118 tests PASS
- format: PASS
- lint: PASS
- typecheck: PASS
- build: PASS
- git diff --check: PASS

## Hosted Supabase verification

Managed migration:

- `fin_p2a_shift_funding_bridge`  applied successfully.

Catalog:

- three shift funding provenance columns present;
- `finance_open_shift_from_main_cash` present;
- legacy `cs05_open_my_shift` replaced with positive-opening fail-closed behavior;
- both public command RPCs use pinned empty `search_path`.

## Hosted behavior regression

A transaction-scoped Owner/Kasir regression was executed and rolled back.

Verified:

- Owner test capital seeded Kas Utama through FIN-P1 command.
- positive opening through legacy RPC is rejected with `FINANCE_OPENING_SOURCE_REQUIRED`.
- Kasir funded-open from Kas Utama succeeds when shift permission and funds are valid.
- shift provenance records `KAS_UTAMA` and the canonical movement id.
- exactly one `SHIFT_OPENING` money movement exists from Kas Utama to Kas Shift.
- replay with the same idempotency key returns the same shift and does not duplicate the transfer.
- a second independent open while the actor already owns an active shift is rejected.
- all test facts were rolled back.

## Security advisor disposition

No new security ERROR was introduced.

The authenticated SECURITY DEFINER warning for the new public command RPC is intentional: execution is limited to authenticated users, `search_path` is pinned, current shift/session/business authority is independently checked, and hosted behavior regression validates the boundary.

## Roadmap accounting

FIN-P2A is a partial finance milestone checkpoint. No partial roadmap weight is invented.

Whole-project earned progress remains 78.0%.

## Next action

FIN-P2B  Shift Expense Fact:

- one business expense fact;
- amount/category/description/timestamp/actor/actual shift/funding account;
- `EXPENSE_SHIFT_CREATE` authority;
- own-shift read for Kasir and consolidated read for Owner;
- canonical EXPENSE money movement from Kas Shift;
- no duplicate Owner transaction;
- approval state only within locked authority.
