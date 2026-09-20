# UAT BLOCKER RECOVERY PLAN

Date: 2026-09-20
Branch: work/cs06743-patch3-hardening
Trigger: UAT Wave 1 real-device screenshots
Status: ACTIVE

## Findings

### UAT-P1-001  Sales UI missing

Observed:

- /jual renders only SalesFoundationScreen placeholder.
- No product list, cart, checkout, or payment controls are reachable.
- Current backend authority already exposes public.checkout_sale(uuid,uuid,jsonb,jsonb,text).
- Legacy/refinement authority requires Jual, Cart/Checkout, Tunai, QRIS, Transfer, and Kasbon flows.

Disposition:

- P1 release/UAT blocker.
- Do not continue transactional sales UAT until corrected.

Recovery:

1. Replace SalesFoundationScreen with a real Sales module.
2. Reuse existing checkout_sale authority; do not create a second transaction writer.
3. Preserve shift-required behavior and current permissions.
4. Restore product/search/cart/checkout/payment UI family.
5. Preserve manual QRIS policy currently locked for Next.
6. Add source + UI regression tests and real-device rerun.

### UAT-P1-002  Inventory/Purchase UI missing

Observed:

- Home/router expose no Stock/Inventory/Purchase operational screens.
- CS-06 backend/domain objects exist, but the operational UI family is not reachable.

Disposition:

- P1 release/UAT blocker.

Recovery:

1. Add Stock/Inventory entry point with current balances/search/empty states.
2. Add Purchase/Supplier/GRN navigation appropriate to permission.
3. Reuse existing CS-06 RPC/table authority; no duplicate write path.
4. Add Home navigation and route guards.
5. Rerun UAT-08 and UAT-31/32.

### UAT-P2-001  Expense Approval back-link encoding

Observed:

- Android Chrome screenshot renders malformed replacement glyph before Beranda.

Disposition:

- P2 visual defect.
- Fix in the same recovery batch.

## Master-data prerequisite

Hosted verification on 2026-09-20 returned:

- active public.products rows: 0
- active public.stock_items rows: 0

The source-controlled CS-02/CS-06 work explicitly did not claim a populated production-data restore.

Therefore Wave 1B sales/inventory transactions are BLOCKED until a canonical master-data source is selected/imported.

Rules:

- Do not invent products or selling prices.
- Do not silently seed production/UAT master data from memory.
- Prefer migration/import from the actual Segeran Jiwa legacy authority or another explicitly approved canonical dataset.
- Keep test fixtures transaction-scoped/rollback unless a dedicated UAT dataset is deliberately created.

## Recovery gate

UAT Wave 1 may resume transactional testing only when:

1. /jual is no longer a placeholder;
2. Stock/Purchase pages are reachable;
3. canonical sales master data exists for the UAT environment;
4. full npm run verify passes;
5. hosted regression for affected write paths passes;
6. UAT-06 and UAT-08 are rerun on the real device and no P1 remains.

## Roadmap impact

Do not start FIN-P7 while these UAT P1 findings are open.

The existing 78% figure remains the weighted implementation-roadmap score; it must not be described as 78% end-user/cutover readiness.
