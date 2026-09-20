# FIN-P5 CHECKPOINT REPORT

Project: segeran-jiwa-pos-next  
Checkpoint: FIN-P5 Supplier Payable Foundation  
Date: 2026-09-20  
Branch: work/cs06743-patch3-hardening  
Status: LOCKED_REMOTE after final safepoint push

## Authority

FIN-P5 implements the locked supplier-payable rules:

- purchase may resolve as payment or Utang Pemasok;
- Utang Pemasok supports partial payment;
- Supplier Payable is part of the minimum finance account set;
- global Supplier Payable is not exposed to ordinary Kasir;
- all money effects remain in the canonical money ledger.

Supplier-return stock/refund correction is not invented in this checkpoint. It requires a canonical supplier-return stock flow and remains a bounded follow-up.

## Source safepoints

- Planning: 81172900d60079db556f3bff928b83b0f3c66d83
- P5 foundation: 83027b4748dc8f35b7eae59d4102e561e97c3c41
- P5A method-based payment API: c6f3041ca2c498a07833eb19dd7f06845fba676f
- P5B supplier read authority: b77c1d1f3a4a28c5b220a66b93f03e524e8784c9

## Implemented contract

FIN-P5 adds:

- canonical money account `UTANG_PEMASOK`;
- immutable `supplier_payables`;
- immutable `supplier_payable_payments`;
- security-invoker `supplier_payable_balances`;
- `finance_create_supplier_payable`;
- method-based `finance_pay_supplier_payable(..., CASH|TRANSFER, ...)`;
- Owner/PURCHASE_MANAGE read boundary;
- PAYMENT_TRANSFER requirement for BANK settlement;
- operation idempotency and audit events.

Payable creation requires a POSTED goods receipt. The supplier invoice amount is explicit; FIN-P5 does not invent partial-GRN tax/discount/freight allocation rules.

## Money semantics

- Payable creation: canonical ADJUSTMENT from UTANG_PEMASOK, producing a negative liability balance.
- Payment: canonical TRANSFER from KAS_UTAMA or BANK to UTANG_PEMASOK.
- Supplier payment is not new INCOME.
- Supplier payment is not a second operating EXPENSE.

## TDD and regression

P5 source test was RED before the migration existed and GREEN after implementation.

P5A was added after audit found that a non-Owner PURCHASE_MANAGE user could not safely discover Owner-only money-account UUIDs. The public API now accepts CASH/TRANSFER and resolves the canonical account server-side.

P5B was added after hosted regression found that the security-invoker balance view could not read supplier names because suppliers lacked an authenticated SELECT boundary. The legacy tenant-wide supplier policy was replaced by an Owner/PURCHASE_MANAGE SELECT policy.

Final source verification before checkpoint documentation:

- JS: 73/73 PASS
- Python: 139/139 PASS
- format: PASS
- lint: PASS
- typecheck: PASS
- build: PASS
- git diff --check: PASS

## Hosted verification

Managed migrations applied successfully:

- fin_p5_supplier_payable_foundation
- fin_p5a_supplier_payment_method_api
- fin_p5b_supplier_read_authority

Hosted transaction-scoped regression returned:

`FIN_P5_HOSTED_REGRESSION_PASS`

The regression verified:

- unauthorized create denied;
- POSTED-GRN payable creation;
- create idempotency;
- partial CASH payment;
- payment idempotency;
- TRANSFER denied without PAYMENT_TRANSFER;
- TRANSFER allowed after explicit permission;
- OPEN -> PAID derived balance/status;
- overpayment rejection;
- Supplier and payable RLS isolation for ordinary Kasir;
- Owner ledger visibility;
- supplier-payment money movements are TRANSFER;
- supplier payments are not INCOME/EXPENSE;
- payable creation is linked to the UTANG_PEMASOK liability movement.

The transaction was rolled back after verification.

## Advisor disposition

No checkpoint-owned security ERROR or unindexed-foreign-key finding remains.

Security-definer warnings for the two public FIN-P5 RPCs are intentional API boundaries: both RPCs perform explicit authority/permission checks and restrict direct table writes.

Unused-index INFO findings are expected on newly created tables before production traffic exists.

## Verdict

CLEAR. FIN-P5 Supplier Payable Foundation is locked.

The full Finance 10% roadmap bucket remains unearned until the complete Finance acceptance gate is closed.

## Next action

FIN-P6 Expense Approval.

The next phase must implement only the locked rule that Owner can configure expense approval by amount/category; it must not invent unrelated month-close or employee-Kasbon repayment semantics.
