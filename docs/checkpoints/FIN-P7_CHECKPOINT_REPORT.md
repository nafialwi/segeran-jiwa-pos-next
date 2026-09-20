# FIN-P7 CHECKPOINT REPORT

Project: segeran-jiwa-pos-next
Checkpoint: FIN-P7 Employee Kasbon Foundation
Date: 2026-09-20
Branch: work/cs06743-patch3-hardening
Status: LOCKED_REMOTE after final safepoint push

## Authority

Blueprint v1.0 FINAL LOCK requires Employee Kasbon to be separate from Customer Debt and used only for employees. Repayment/deduction mechanics remain explicitly deferred to a later Blueprint decision.

FIN-P7 implements only that bounded foundation. It does not invent payroll deduction, installments, repayment schedules, due dates, interest, or payroll integration.

## Source safepoint

- Technical implementation: f3349357d7b9711e1796112bde0db2baaa4e1675
- Managed hosted migration: fin_p7_employee_kasbon_foundation

## Implemented contract

FIN-P7 adds:

- canonical `KASBON_KARYAWAN` money account;
- immutable `employee_kasbons` finance fact;
- Owner-only security-invoker `employee_kasbon_balances` projection;
- `finance_create_employee_kasbon` idempotent command;
- explicit CASH funding from `KAS_UTAMA`;
- explicit TRANSFER funding from `BANK`;
- canonical TRANSFER money movement into `KASBON_KARYAWAN`;
- audit and operation-receipt evidence;
- active non-Owner business membership as the employee target authority.

FIN-P7 reuses the existing `profiles + business_memberships` staff identity. It does not create a second employee master.

## Accounting semantics

Employee Kasbon is not an operating expense and not customer debt.

Creation transfers business value from a real liquid funding account to the employee-receivable account:

- CASH: `KAS_UTAMA -> KASBON_KARYAWAN`;
- TRANSFER: `BANK -> KASBON_KARYAWAN`.

The original Kasbon fact is immutable.

Because repayment authority is not yet locked by Blueprint, FIN-P7 intentionally has no repayment fact or command. The foundation balance projection reports `paid_amount = 0`, `balance = original_amount`, and `status = OPEN`.

## Security boundary

- Create command is Owner-only.
- Employee target must be an active non-Owner member of the same business.
- Owner cannot be used as an Employee Kasbon target.
- Non-Owner staff cannot read Employee Kasbon business finance.
- `EMPLOYEE_MANAGE` by itself does not grant finance visibility or disbursement authority.

## TDD and source verification

The FIN-P7 source test was RED before the migration existed and GREEN after implementation.

Final technical verification:

- JS: 73/73 PASS
- Python: 163/163 PASS
- format: PASS
- lint: PASS
- typecheck: PASS
- build: PASS
- git diff --check: PASS

## Hosted verification

Managed migration applied successfully:

- `fin_p7_employee_kasbon_foundation`

Transaction-scoped hosted regression returned:

`FIN_P7_HOSTED_REGRESSION_PASS`

The regression verified and rolled back:

- CASH Kasbon from KAS_UTAMA;
- TRANSFER Kasbon from BANK;
- receivable balance increase in KASBON_KARYAWAN;
- source-account balance decrease;
- money movement type TRANSFER, not INCOME/EXPENSE;
- command replay returns the same Kasbon and does not duplicate facts/movements;
- insufficient funding is rejected;
- Owner target is rejected;
- Owner can read the projection;
- non-Owner cannot read the projection or create Kasbon;
- Kasbon fact is immutable.

No test Kasbon or test employee persisted.

## Advisor disposition

No FIN-P7-owned RLS gap or security ERROR was reported.

The generic security-definer advisor warns that authenticated users can invoke `finance_create_employee_kasbon`. This is intentional API exposure: the RPC performs a server-side hard Owner check. Hosted negative regression proves a non-Owner call is rejected.

Unused-index INFO findings for new FIN-P7 indexes are expected before production workload and are not a checkpoint blocker.

## Explicitly deferred

FIN-P7 does not implement:

- Kasbon repayment;
- salary/payroll deduction;
- automatic installment;
- repayment schedule;
- due date;
- interest/fee;
- employee self-service;
- historical Legacy Kasbon migration.

These remain outside locked authority.

## Verdict

CLEAR. FIN-P7 Employee Kasbon Foundation is locked.

The Finance 10% roadmap bucket remains unearned until the Finance milestone acceptance/closure audit is locked.

## Next action

Finance milestone acceptance / closure audit across FIN-P1 through FIN-P7.
