# FIN-P7 Employee Kasbon Foundation Design

Date: 2026-09-20
Blueprint baseline: v1.0 FINAL LOCK
Status: IMPLEMENTATION-BOUND DESIGN

## Authority

The locked Blueprint establishes only these Employee Kasbon rules:

- Kasbon Karyawan is separate from Hutang Pelanggan.
- Kasbon is used only for employees.
- Repayment/deduction mechanics are deferred to a later authority decision.
- All financial effects must use the single Finance money engine.

FIN-P7 therefore must not invent salary deduction, automatic installments,
repayment schedules, due dates, interest, or payroll integration.

## Identity authority

FIN-P7 does not create a second employee master.

A current employee target is represented by an existing non-Owner
`profiles` row with an active `business_memberships` row in the same
business. This reuses the locked staff identity authority and avoids identity
drift between user/staff and finance records.

The Owner profile is not a target for Employee Kasbon.

## Financial authority

Add canonical account:

- `KASBON_KARYAWAN` / Kasbon Karyawan / OTHER

Creating a Kasbon is not an operating expense. It is a balance-sheet transfer:

- source: explicit liquid business account, restricted to `KAS_UTAMA` or
  `BANK`;
- destination: `KASBON_KARYAWAN`;
- movement type: `TRANSFER`;
- source type: `EMPLOYEE_KASBON`.

This preserves the real source of funds and the single money ledger.

## Data authority

Add immutable `employee_kasbons` with:

- business;
- employee profile;
- original amount;
- funding account;
- canonical money movement;
- creator/actor;
- note;
- created timestamp.

Add security-invoker `employee_kasbon_balances` projection. In FIN-P7,
because repayment mechanics are intentionally absent, the projection reports:

- original_amount;
- paid_amount = 0;
- balance = original_amount;
- status = OPEN.

A later approved milestone may replace the projection with repayment-derived
facts without mutating the original Kasbon fact.

## Command

`finance_create_employee_kasbon(employee_profile_id, source_method, amount, note, idempotency_key)`

- Owner-only.
- source_method is CASH or TRANSFER:
  - CASH resolves to KAS_UTAMA;
  - TRANSFER resolves to BANK.
- Source account must have sufficient balance.
- Target must be a non-Owner active business member.
- Command is idempotent.
- One canonical money movement and one immutable Kasbon fact are created.
- Retry returns the same Kasbon.
- No repayment command is introduced.

## Read boundary

Employee Kasbon is business finance. FIN-P7 keeps its facts and projection
Owner-only. EMPLOYEE_MANAGE alone does not grant finance visibility or payout
authority.

## Explicitly out of scope

- salary/payroll;
- automatic salary deduction;
- installments;
- manual repayment;
- due dates;
- interest/fees;
- employee self-service;
- Kasbon approval workflow;
- historical Legacy Kasbon migration.
