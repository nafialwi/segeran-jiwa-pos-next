# UAT WAVE 1  CORE OPERATIONS

Date: 2026-09-20
Branch: work/cs06743-patch3-hardening
Baseline commit: 27b16117c3a2e8869955996da26ce6abcd9a935a
Scope: Core operational UAT before FIN-P7
Status: IN_PROGRESS

## Purpose

Validate the locked core on a real browser/device before more milestones are stacked on top.

This is not final cutover UAT.

## Result vocabulary

- PASS  expected behavior and visual result are correct.
- FAIL  functional/business/permission failure.
- OBSERVATION  usable but needs UX/visual follow-up.
- NOT_RUN  not tested yet.
- BLOCKED  cannot be tested because a prerequisite is unavailable.

## Safety boundary

Wave 1A is read-only/smoke where possible.
Wave 1B performs controlled writes only after the operator explicitly begins the transactional section.
Production automatic deployment remains disabled.

## Wave 1A  Smoke, responsive and navigation

| ID     | Scenario                      | Expected                              | Result  |
| ------ | ----------------------------- | ------------------------------------- | ------- |
| UAT-01 | App loads current branch      | No blank page/loading blocker         | NOT_RUN |
| UAT-02 | Login screen/session restore  | Human-readable state, no overflow     | NOT_RUN |
| UAT-03 | Home desktop                  | Main navigation readable and aligned  | NOT_RUN |
| UAT-04 | Home mobile-width             | No horizontal overflow/cut text       | NOT_RUN |
| UAT-05 | Shift page opens              | Current shift state readable          | NOT_RUN |
| UAT-06 | Sales page opens              | Checkout controls readable            | NOT_RUN |
| UAT-07 | Reconciliation page opens     | Totals/status readable                | NOT_RUN |
| UAT-08 | Inventory/purchase navigation | Core pages reachable                  | NOT_RUN |
| UAT-09 | Owner-only navigation         | Owner cards visible only to Owner     | NOT_RUN |
| UAT-10 | Approval Pengeluaran screen   | Rule + queue UI loads without error   | NOT_RUN |
| UAT-11 | Unauthorized route            | Access denied is human-readable       | NOT_RUN |
| UAT-12 | Refresh/reopen                | Current route/session recovers safely | NOT_RUN |

## Wave 1B  Controlled operational flow

| ID     | Scenario                           | Expected                                  | Result  |
| ------ | ---------------------------------- | ----------------------------------------- | ------- |
| UAT-20 | Open shift from main cash          | Shift opens once, opening cash visible    | NOT_RUN |
| UAT-21 | Cash sale                          | Sale succeeds and expected cash updates   | NOT_RUN |
| UAT-22 | Manual QRIS sale                   | QR displayed/manual confirm flow works    | NOT_RUN |
| UAT-23 | Transfer sale                      | Payment recorded under correct method     | NOT_RUN |
| UAT-24 | Customer debt sale                 | Debt created, not treated as cash receipt | NOT_RUN |
| UAT-25 | Small expense without approval     | Posts immediately                         | NOT_RUN |
| UAT-26 | Expense over threshold             | Becomes PENDING; no cash effect yet       | NOT_RUN |
| UAT-27 | Owner approves expense             | Expense posts exactly once                | NOT_RUN |
| UAT-28 | Owner rejects expense              | No expense/cash posting                   | NOT_RUN |
| UAT-29 | Shift reconciliation               | Expected cash is correct                  | NOT_RUN |
| UAT-30 | Close shift                        | Closing succeeds only with valid state    | NOT_RUN |
| UAT-31 | Purchase/supplier basic navigation | PO/GRN workflow reachable                 | NOT_RUN |
| UAT-32 | Supplier payable view              | Authorized finance/purchase access only   | NOT_RUN |

## Severity

- P0  data corruption/security/ledger integrity; stop UAT and fix immediately.
- P1  core flow unusable or materially wrong; fix before continuing roadmap.
- P2  UX/visual friction; record and continue if safe.
- P3  cosmetic.

## Exit gate for Wave 1

Wave 1 is CLEAR when:

1. no open P0/P1 finding remains;
2. core pages have desktop and mobile evidence;
3. login/permission/shift/sales/expense approval paths have real-device evidence;
4. transactional UAT reconciles money/shift outcomes;
5. findings and fixes are committed/pushed to the working branch.
