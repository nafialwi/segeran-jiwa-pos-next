# FIN-P6 Expense Approval Design

**Date:** 2026-09-20

## Authority

Blueprint v1.0 FINAL LOCK states that Kasir may record business expenses when explicitly permitted and Owner can configure approval based on amount/category.

The Blueprint does not define a detailed approval state machine. FIN-P6 therefore uses a fail-closed, accounting-safe interpretation:

- a request that requires approval does not change Shift cash or the canonical money ledger before approval;
- approval may post the expense only while the originating Shift is still OPEN;
- a closed Shift is never changed retroactively by a delayed approval;
- rejection never posts cash or money movements.

## Rule model

Owner can configure one active threshold for:

- a specific normalized category; or
- `*` as the global fallback.

An expense requires approval when any active matching rule has `amount >= min_amount`. A category-specific match takes precedence over the global rule when evidence records the matched rule.

Rules are configuration and may be enabled/disabled through an Owner-only RPC. Every change emits an audit event.

## Append-only approval evidence

`expense_approval_requests` is immutable and records the cashier request.

`expense_approval_decisions` is immutable and records exactly one Owner decision per request.

A security-invoker queue view derives:

- PENDING when no decision exists;
- APPROVED when an approval decision exists;
- REJECTED when a rejection decision exists.

## Posting semantics

Existing `business_expenses` remains the posted expense fact.

A private posting helper creates, atomically:

- EXPENSE money movement from KAS_SHIFT;
- CASH_OUT shift transaction;
- business_expenses fact with approval_state NOT_REQUIRED or APPROVED.

The existing public `finance_post_shift_expense` remains compatible for expenses that do not require approval. If a matching rule exists, it fails closed with `FINANCE_EXPENSE_APPROVAL_REQUIRED`.

The UI uses `finance_submit_shift_expense`:

- no matching rule -> returns POSTED + expense_id;
- matching rule -> returns PENDING + request_id.

Owner uses `finance_decide_expense_request` to approve/reject.

## Access

- cashier submission requires EXPENSE_SHIFT_CREATE;
- cashier can read only their own requests/decisions;
- Owner can read all requests, decisions, and rules;
- rule mutation and approval/rejection are Owner-only;
- direct client writes to rule/request/decision tables are denied.

## UI

- Shift screen submits through the approval-aware RPC and visibly reports PENDING vs POSTED;
- Shift screen shows its approval requests;
- Owner gets an `/expense-approval` screen for rules and pending decisions;
- Home shows an Owner-only Approval Pengeluaran card.

## Deferred

FIN-P6 does not invent:

- month-close/reopen semantics;
- employee-Kasbon repayment/deduction rules;
- multi-stage approval chains;
- delegated non-Owner approvers.
