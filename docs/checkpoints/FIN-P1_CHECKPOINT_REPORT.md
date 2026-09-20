# FIN-P1 CHECKPOINT REPORT

Project: segeran-jiwa-pos-next  
Checkpoint: FIN-P1 Finance Foundation  
Date: 2026-09-20  
Branch: work/cs06743-patch3-hardening  
Planning Safepoint: ebcbd28974734de44d1ac9134bbec6c46b8260f8  
Technical Source Commit: e8cd382ddeea529e14420aaa915250c7a6dda9e2  
Status: LOCKED_REMOTE

## Scope

FIN-P1 establishes the secure finance foundation without creating a second money ledger.

Implemented:

- canonical business-level `KAS_SHIFT` money account;
- Owner-only read RLS for `money_accounts` and `money_movements`;
- `finance_post_transfer` for bounded internal transfers;
- `finance_post_owner_capital` for real Owner capital contribution;
- `finance_post_owner_personal_withdrawal` for Owner personal withdrawal;
- all postings reuse the existing canonical `money_movements` authority and idempotency/audit primitives.

Explicitly deferred:

- business/shift expense fact + approval workflow (FIN-P2);
- customer-debt collection engine;
- employee Kasbon repayment/deduction mechanics;
- QRIS settlement/provider-fee completion;
- month close/reopen;
- finance reports/Excel.

## TDD evidence

RED:

- `tests/test_fin_p1_finance_foundation.py` failed because the FIN-P1 migration did not exist.

GREEN:

- FIN-P1 source contract tests passed.
- migration registry tests passed.
- canonical verification passed after source implementation.

## Canonical verification

Command: `npm run verify`  
Result: CLEAR

- JS: 14 files, 73/73 tests PASS
- Python: 115/115 tests PASS
- format: PASS
- lint: PASS
- typecheck: PASS
- build: PASS
- git diff --check: PASS

## Hosted Supabase verification

Managed migration:

- `fin_p1_finance_foundation`  applied successfully on 2026-09-20.

Catalog checks:

- `KAS_SHIFT` exists, account type CASH, active.
- `money_accounts_owner_read` is the active authenticated SELECT policy.
- `money_movements_owner_read` is the active authenticated SELECT policy.
- old active-member finance read policies are removed.
- FIN-P1 public RPCs exist as SECURITY DEFINER functions with pinned empty `search_path`.
- private finance helpers are not client-executable.

## Hosted behavior regression

A transaction-scoped Owner/Kasir regression was executed and rolled back.

Verified:

- Kasir sees zero business-wide finance accounts.
- Kasir sees zero finance movements/balances.
- Kasir calling an Owner finance RPC is denied with `FINANCE_OWNER_REQUIRED`.
- Owner capital contribution posts one canonical ADJUSTMENT movement and idempotent replay returns the same movement.
- Owner capital increases Kas Utama without classifying it as operating INCOME.
- Kas Utama -> Kas Shift posts one canonical TRANSFER and replay is stable.
- insufficient source balance is rejected with `FINANCE_INSUFFICIENT_BALANCE`.
- Owner personal withdrawal posts ADJUSTMENT with source type `OWNER_PERSONAL_EXPENSE`, not EXPENSE.
- test facts were rolled back.

## Advisor disposition

No new Supabase security ERROR was introduced.

The advisor reports the FIN-P1 public RPCs as authenticated SECURITY DEFINER functions. This is intentional for the command boundary: each RPC is exposed only to `authenticated`, pins `search_path=''`, and independently requires current Owner authority before writing through the private canonical ledger. Hosted Kasir-denial behavior was explicitly tested.

Existing project INFO/WARN items outside FIN-P1 remain separate backlog items.

## Roadmap accounting

FIN-P1 is a partial milestone checkpoint. The full 10% finance roadmap bucket remains unearned until the complete Expense, Debt, Kasbon & Finance Engine acceptance gate is locked.

Whole-project earned progress therefore remains 78.0%.

## Next action

FIN-P2  Pengeluaran Usaha / Pengeluaran Shift integration:

- one business expense fact;
- Shift/Kas/Keuangan/Aktivitas linkage;
- permission `EXPENSE_SHIFT_CREATE`;
- Owner approval rules only where already supported by locked authority;
- no duplicate Owner transaction and no second ledger.
