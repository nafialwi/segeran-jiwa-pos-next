# FIN-P6 CHECKPOINT REPORT

Project: segeran-jiwa-pos-next  
Checkpoint: FIN-P6 Expense Approval  
Date: 2026-09-20  
Branch: work/cs06743-patch3-hardening  
Status: LOCKED_REMOTE after final safepoint push

## Authority

Blueprint v1.0 FINAL LOCK states that business expense entry is permission-bounded and Owner can configure approval based on amount/category.

FIN-P6 implements that locked rule without inventing a multi-stage workflow or payroll semantics.

## Source safepoints

- Planning: 3e27f4cf7fa5db347a958922376c69945f88878f
- Technical implementation: e8195d0f1cde2c47295a35a22fbe5abb5aff54e8

## Implemented contract

FIN-P6 adds:

- `expense_approval_rules` with category-specific or `*` global threshold;
- immutable `expense_approval_requests`;
- immutable `expense_approval_decisions`;
- security-invoker `expense_approval_queue`;
- Owner-only rule configuration RPC;
- approval-aware shift expense submission RPC;
- Owner approve/reject RPC;
- anti-bypass gate on the legacy direct expense RPC;
- Owner Approval Pengeluaran screen and route;
- cashier request-status visibility on Shift screen.

## Accounting and shift semantics

If no rule matches, the expense posts normally.

If a rule matches:

- request status is PENDING;
- no `business_expenses` fact is created yet;
- no CASH_OUT is created;
- no money movement is created.

Approval creates the canonical EXPENSE money movement, CASH_OUT and business expense fact atomically with `approval_state=APPROVED`.

Rejection posts no cash or money effect.

Approval is fail-closed when the originating Shift has already been CLOSED, preventing delayed approval from mutating a completed Shift.

## TDD and source verification

The FIN-P6 source test was RED before migration/UI implementation and GREEN afterward.

A prior FIN-P2B regression was updated only to reflect the new approval-aware public API; its original requirement remains intact: typed expense submission replaces generic cash movement entry.

Final technical source verification:

- JS: 73/73 PASS
- Python: 142/142 PASS
- format: PASS
- lint: PASS
- typecheck: PASS
- build: PASS
- git diff --check: PASS

## Hosted verification

Managed migration applied successfully:

- `fin_p6_expense_approval`

Transaction-scoped hosted regression returned:

`FIN_P6_HOSTED_REGRESSION_PASS`

The regression verified:

- no-rule expense posts directly;
- Owner creates a global threshold rule;
- matching expense becomes PENDING;
- pending request is idempotent;
- pending request has no expense/cash/money effect;
- direct expense RPC cannot bypass a matching rule;
- non-Owner decision is denied;
- ordinary unrelated cashier cannot read the queue;
- cashier cannot read Owner approval rules;
- Owner approval creates exactly one approved expense with CASH_OUT and EXPENSE money movement;
- approval decision is idempotent;
- Owner rejection creates no expense;
- approval after Shift closure is denied;
- shift closure reconciles correctly after approved expenses.

All hosted regression fixtures were rolled back.

## Advisor disposition

No checkpoint-owned security ERROR or unindexed-foreign-key finding remains.

Security-definer warnings for:

- `finance_submit_shift_expense`
- `finance_set_expense_approval_rule`
- `finance_decide_expense_request`

are intentional API boundaries. Each RPC performs explicit authenticated authority checks; rule/decision RPCs enforce Owner-only behavior where required.

Unused-index INFO findings are expected for newly created tables prior to production traffic.

## Verdict

CLEAR. FIN-P6 Expense Approval is locked.

The full Finance 10% roadmap bucket remains unearned until the entire Finance milestone acceptance gate is closed.

## Next action

FIN-P7 Employee Kasbon Foundation.

FIN-P7 must establish a separate employee-Kasbon authority before cutover, but must not invent payroll deduction or repayment schedules that are not locked by the Blueprint.
