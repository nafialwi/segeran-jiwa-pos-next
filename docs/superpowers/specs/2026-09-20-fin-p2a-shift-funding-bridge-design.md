# FIN-P2A Shift Funding Bridge Design

**Date:** 2026-09-20  
**Baseline:** FIN-P1 LOCKED_REMOTE at e743925aa2325ff2ee4386514a703f159e4c414b

## Problem

Current CS-05 allows a positive opening balance to be supplied directly to `cs05_open_my_shift` without recording where that money came from. That conflicts with the locked rule that money may not appear without an explicit source and movement.

## Locked authority

- Shift is operational context, not a second money ledger.
- Opening cash must have a selected source.
- Kas Utama -> Kas Shift is an internal transfer, not income/expense.
- Setoran Owner increases capital only when it is genuinely new external money.
- Business commands must be idempotent.
- Kasir may open/close their own shift when permitted, but may not read global finance.

## FIN-P2A scope

This checkpoint implements the first funded-opening path: **Kas Utama -> Kas Shift**.

### Schema provenance

Add nullable historical-compatible fields to `shifts`:

- `opening_source_type`
- `opening_source_ref`
- `opening_money_movement_id`

New funded opens write:

- source type `KAS_UTAMA`;
- source ref = Kas Utama account UUID;
- movement id = canonical TRANSFER movement.

Zero opens write source type `ZERO` and no money movement.

Historical shifts are not rewritten.

### Legacy API hardening

`cs05_open_my_shift(location, opening, config)` remains callable for compatibility.

- opening = 0: allowed and records source `ZERO`;
- opening > 0: rejected with `FINANCE_OPENING_SOURCE_REQUIRED`.

This prevents positive money from appearing without source while preserving zero-balance workflows.

### Funded open RPC

Add:

`finance_open_shift_from_main_cash(location, opening, config, idempotency_key)`

Behavior:

1. require current `SHIFT_OPEN_CLOSE` authority;
2. validate location belongs to current business;
3. require opening > 0;
4. resolve active `KAS_UTAMA` and `KAS_SHIFT`;
5. require sufficient canonical Kas Utama balance;
6. outer idempotency lock for the whole shift-open command;
7. open the shift through the existing private shift authority;
8. post one canonical `TRANSFER` from Kas Utama to Kas Shift;
9. persist shift funding provenance;
10. record command success;
11. replay same key returns the same shift and does not duplicate movement.

All work occurs in one PostgreSQL transaction.

### Immutability

Opening-source provenance is immutable after creation.

### Frontend

The current shift-open UI is changed so:

- positive opening balance uses the new funded-open RPC;
- zero opening uses the legacy zero-open path;
- user sees source label `Kas Utama` for funded opening;
- finance balance itself is not exposed to Kasir.

## Deferred

- Setoran Owner as a direct open-shift source;
- handover-funded open;
- configurable other allowed sources;
- shift expense fact (FIN-P2B after this bridge).

## Acceptance

- positive legacy open is denied;
- zero legacy open remains valid;
- funded open creates exactly one shift and one canonical TRANSFER;
- replay returns same shift/movement semantics;
- insufficient Kas Utama balance is rejected atomically;
- Kasir still cannot read global finance;
- source provenance is visible on own shift and immutable;
- local full verify PASS;
- hosted regression PASS;
- checkpoint committed and pushed.
