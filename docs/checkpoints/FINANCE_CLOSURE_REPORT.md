# FINANCE MILESTONE CLOSURE REPORT

Project: segeran-jiwa-pos-next
Milestone: Expense, Debt, Kasbon & Finance Engine
Date: 2026-09-20
Branch: work/cs06743-patch3-hardening
Status: LOCKED_REMOTE / CLEAR

## Authority baseline

Blueprint v1.0 FINAL LOCK is the business authority.

The Finance milestone closes only the rules already locked by that Blueprint. It does not invent:

- Employee Kasbon repayment/payroll deduction mechanics;
- month close/reopen semantics;
- finance reporting/Excel semantics that belong to the next roadmap bucket.

## Closed checkpoint chain

- FIN-P1 Finance Foundation
- FIN-P2A Shift Funding Bridge
- FIN-P2B Shift Expense
- FIN-P3 Customer Debt Foundation
- FIN-P4 QRIS Settlement & Daily Finance Reconciliation
- FIN-P5 Supplier Payable Foundation
- FIN-P6 Expense Approval
- FIN-P7 Employee Kasbon Foundation
- Finance closure hardening for Modal and Pengeluaran Pribadi canonical accounts
- Owner Finance Front Door

## Final source safepoints

- FIN-P7 technical source: f3349357d7b9711e1796112bde0db2baaa4e1675
- FIN-P7 checkpoint: c275cda3c4be696147e03f0462bfd1848bc38a19
- Modal/Prive closure hardening: feb71bcb3ab3f0bbbc02c955b96f7f0edaa4b6aa
- Owner Finance Front Door: 29d4bff82c40888157f201433f0185d644cc5b96

## Blueprint acceptance matrix

### One money engine

CLEAR.

All finance effects use canonical `money_movements`. No second finance ledger was created.

### Minimum accounts

CLEAR.

Hosted canonical account set now contains:

- KAS_UTAMA
- KAS_SHIFT
- BANK
- QRIS_BELUM_CAIR
- QRIS_SUDAH_CAIR
- HUTANG_PELANGGAN
- UTANG_PEMASOK
- MODAL
- PENGELUARAN_PRIBADI

FIN-P7 additionally adds KASBON_KARYAWAN as the separate Employee Kasbon receivable authority.

### Internal transfer semantics

CLEAR.

Kas Utama / Kas Shift / Bank transfers are TRANSFER movements and do not create operating income or expense.

### Owner capital

CLEAR.

Modal Owner is represented as a two-sided ADJUSTMENT:

MODAL -> KAS_UTAMA/BANK

It is not operating income.

### Owner personal withdrawal

CLEAR.

Pengeluaran Pribadi Owner is represented as a two-sided ADJUSTMENT:

KAS_UTAMA/BANK -> PENGELUARAN_PRIBADI

It is not operating expense and does not reduce operating profit.

The Owner Finance UI presents this action in a separate section and requires an explicit confirmation explaining the reporting impact before save.

### Business / Shift expense

CLEAR.

Expense input is linked to Shift, cash, finance, and audit facts. Owner approval by category/amount threshold is operational. Pending requests are financially inert until approval.

### Customer debt

CLEAR.

Customer debt is created from CREDIT sale, supports partial payment, tracks historical payment facts, and payment is not a new sale.

### Employee Kasbon

CLEAR for the locked foundation.

Employee Kasbon is separate from Customer Debt and only targets active non-Owner staff.

Creation is a canonical transfer from KAS_UTAMA or BANK into KASBON_KARYAWAN.

Repayment/deduction mechanics remain intentionally absent because Blueprint authority is deferred.

### Supplier payable

CLEAR.

Purchase/GRN payable authority and payment flow are canonical. Paying a supplier payable does not create a new operating expense.

### QRIS

CLEAR.

QRIS sale value enters QRIS_BELUM_CAIR. Settlement moves gross value through QRIS_SUDAH_CAIR, provider fee is recorded separately, and net value reaches BANK.

### Daily reconciliation

CLEAR.

Daily reconciliation checks:

- expected cash vs counted cash;
- QRIS recorded vs settled;
- transfer recorded vs received;
- stock status when available.

Result is SESUAI or PERLU_DIPERIKSA.

### Month close

CORRECTLY DEFERRED.

Blueprint states Owner-only but explicitly defers detailed authority/reopen rules. No month-close/reopen function exists. This is an authority-preserving omission, not a milestone defect.

## Finance Front Door

Owner now has a real `/keuangan` operational screen.

The screen exposes:

- account balances;
- Pindah Uang;
- Modal Owner;
- Settlement QRIS;
- Rekonsiliasi Harian;
- Hutang Pelanggan collection;
- Utang Pemasok payment;
- Kasbon Karyawan creation;
- Approval Pengeluaran navigation;
- separate Pengeluaran Pribadi Owner action with reporting warning.

The route is Owner-only.

No unapproved month-close UI was added.

## Final source verification

Canonical verify after the Finance Front Door:

- JS: 73/73 PASS
- Python: 172/172 PASS
- format: PASS
- lint: PASS
- typecheck: PASS
- build: PASS
- git diff --check: PASS

## Hosted closure evidence

Final aggregate hosted regression:

`FINANCE_CLOSURE_HOSTED_PASS`

It verified:

- all Blueprint minimum Finance accounts exist;
- canonical Finance RPC set exists;
- no unlocked month-close/reopen RPC exists;
- non-Owner cannot read business-wide money accounts or movements;
- non-Owner cannot read Employee Kasbon finance;
- non-Owner cannot invoke Owner transfer/capital authority.

All test identities/facts were rolled back.

Additional closure hardening regression:

`FINANCE_OWNER_ACCOUNTS_HOSTED_PASS`

It verified:

- Modal and Pengeluaran Pribadi are two-sided;
- both remain ADJUSTMENT facts;
- neither is misclassified as INCOME/EXPENSE;
- idempotent replay is stable;
- Owner-only authority is enforced.

## Advisor disposition

No Finance-closure security ERROR was introduced.

Supabase advisor WARN findings for authenticated SECURITY DEFINER Finance RPCs are intentional command boundaries. Each command performs explicit server-side authority checks and negative non-Owner behavior has been hosted-tested.

Unused-index INFO findings are not closure blockers before production workload.

## Verdict

CLEAR.

The Expense, Debt, Kasbon & Finance Engine roadmap bucket is accepted at 100%.

Roadmap earned weight:

- Finance weight: 10%
- Finance earned: 10.0%
- Whole-project earned progress: 88.0%

## Next action

Begin bounded authority audit and implementation planning for:

History, Reversal/Refund, Reports & Excel.
