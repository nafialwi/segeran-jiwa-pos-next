# C3-B Sales Facts & Board 02 Checkout Convergence — SAFEPOINT

Date: 2026-09-22

Branch: `work/cs06743-patch3-hardening`

## Outcome

C3-B closes the remaining factual gaps between the V2 sale engine and the approved Board 02
checkout experience.

The sale path now preserves first-class facts for:

- Product + Variant identity;
- line-level item note;
- discount type/value/reason/approver;
- subtotal / discount / total;
- cash tendered;
- cash change;
- payment method;
- immutable component consumption;
- authoritative History projection.

The cashier flow also gains the Board 02 interaction structure needed before RC2:

```
Product
  -> Pick Variant
  -> Cart
  -> Item Note / Discount
  -> Payment
  -> one authoritative success screen
  -> History
```

This remains source-only refinement. No persistent C2/C3 migration and no new Cloudflare Preview
were created.

## Baseline preserved

C3-B started from:

- C3-A safe commit:
  `6d601a8cc412742016ebc41b168aa83d7c7965b5`
- branch:
  `work/cs06743-patch3-hardening`
- immutable RC1:
  `uat-rc-20260921-1 -> e844f9b9ad07ca240e1ba4f72a39c6c7aefbb489`
- RC1 Preview:
  `https://5188a6b0.segeran-jiwa-pos-next.pages.dev`
- Production automatic deployment: **DISABLED**

## New permission authority

C3-B introduces the permission definition:

`SALE_DISCOUNT`

The discount writer requires this permission for any non-zero discount.

Owner continues to satisfy permission checks through the existing Owner authority.
Cashier access remains explicit through the existing permission model; C3-B does not silently grant
discount authority to every cashier.

## Immutable discount facts

`public.sales` gains:

- `discount_type`: `NONE | AMOUNT | PERCENT`;
- `discount_value`;
- `discount_reason`;
- `discount_approved_by`.

Constraints preserve the historical meaning of the sale:

- NONE means zero discount and no reason/approver;
- AMOUNT must equal `discount_amount`;
- PERCENT must reproduce `discount_amount` from the sale subtotal;
- discounted sales require a reason and approver;
- `total_amount = subtotal - discount_amount`.

The amount actually posted to the money engine is the final sale total, never the cash tendered
amount.

## Cash tender / change facts

`public.payments` gains:

- `tendered_amount`;
- `change_amount`.

For CASH:

```
payment amount = final sale total
change = tendered amount - payment amount
```

Example:

```
Subtotal       10,000
Discount        2,000
Final total     8,000
Tendered       10,000
Change          2,000

Money movement = +8,000
NOT +10,000
```

Non-cash payments keep tender/change null.

Legacy payment rows remain valid because the new tender/change fields are nullable.

## 100% discount semantics

A fully discounted sale is now supported as a real business fact:

```
sale total = 0
inventory consumption = YES
money movement = NO
```

This preserves the core rule that zero-price promo/sample activity may still physically consume
stock.

For a zero-total sale:

- payment method is represented as CASH with amount 0 and tender/change 0;
- no sale money movement is created;
- inventory posting still occurs through the canonical inventory engine.

Refund and Correction were hardened so a zero-total V2 sale can reverse its original inventory
movement without requiring a nonexistent money movement.

No second inventory or finance engine was created.

## Immutable line-note semantics

`public.sale_items` gains:

`line_note`

The note is captured at sale time and becomes part of the immutable sale-line fact.

Typical use:

- “tanpa sedotan”;
- “es sedikit”;
- “packing terpisah”.

The note is intentionally informational. It does not silently change recipe/packaging consumption.
Any stock-consumption difference must still be represented by explicit Product/Variant component
configuration or a later explicit operational movement.

## Checkout V2 authority

The authoritative C3-B checkout signature accepts:

- V2 sale items with `variant_id + quantity + optional line_note`;
- payment;
- discount;
- sale-level note.

Existing 5-argument V2 checkout compatibility is retained as a wrapper with no discount so earlier
C2-B/C2-C tests and callers remain valid during convergence.

The authoritative result returns:

- sale id;
- invoice;
- subtotal;
- discount amount;
- final total;
- payment method;
- tendered amount;
- change amount;
- inventory basis;
- replay status.

## Frontend Board 02 convergence

`src/screens/SalesScreen.tsx` now has:

### Product -> Variant interaction

Catalog variants are grouped under their Sale Product.

- a one-variant product can enter the cart directly;
- a multi-variant product opens **Pilih Varian**;
- variant availability/capacity remains V2-authoritative.

### Cart item notes

Each cart line exposes **Catatan item** and sends the immutable line note to checkout.

### Discount controls

When the active authority has `SALE_DISCOUNT`, checkout exposes:

- no discount;
- nominal discount;
- percentage discount;
- required discount reason.

Without permission the discount control is not shown.

### Checkout totals

The checkout surface now explicitly separates:

- Subtotal;
- Discount;
- Total.

### Cash tender/change

The existing cash UX now submits the tendered amount as a real payment fact.
The server remains authoritative for the resulting change amount.

### Single success authority

The old inline text:

`Penjualan berhasil. Invoice: ...`

is replaced by one success dialog:

`Pembayaran Berhasil`

It shows:

- invoice;
- final total;
- payment method;
- discount if present;
- tendered/change for cash;
- sold item summary.

Actions:

- `Lihat Riwayat` -> canonical `/riwayat`;
- `Transaksi Baru`.

No duplicate success authority is introduced.

## History convergence

Transaction History now reads and exposes:

- line note;
- discount type/value/reason;
- discount approver identity;
- tendered amount;
- change amount;
- existing Product/Variant sale identity.

The History screen presents:

- variant information;
- item note;
- discount information;
- cash tender/change.

Legacy history remains readable because all new facts are nullable/default-safe.

## Real transactional PostgreSQL rehearsal

C2-A + C2-B + C2-C + C3-B and the C3-B integration regression were executed against the hosted
PostgreSQL engine inside one explicit transaction.

The rehearsal covered:

1. create Product/Variant/Component foundation;
2. create V2 sale snapshot/execution authority;
3. create V2 readers;
4. apply C3-B discount/tender/change/line-note facts;
5. discounted CASH sale;
6. persisted line note;
7. payment amount vs tender/change validation;
8. 100% discounted sale with stock consumption and no money movement;
9. zero-total Refund;
10. zero-total Correction;
11. History visibility of new facts;
12. final inventory balance checks;
13. rollback.

The first rehearsal exposed a real C3-B defect:

- `line_note` entered the request-normalization JSON but was not propagated into the resolved
  immutable sale-line JSON.

That defect was corrected and the C3-B source contract test was strengthened.

A second rehearsal then exposed a test-fixture privilege mistake when the test attempted to read
`public.sales` directly after switching to the authenticated role.

The test was corrected to resolve the invoice before the role switch; production authority was not
weakened.

Final transactional rehearsal result:

**PASS**

Post-rollback verification:

- persisted C2 tables: **0**;
- persisted C3-B columns: **0**;
- persisted `SALE_DISCOUNT` permission: **0**;
- persisted isolated fixture profile: **0**.

Therefore the hosted operational database remains unchanged.

## UI hardening found during final review

Two UI defects were caught before checkpoint:

1. Success action pointed to noncanonical `/history`; corrected to `/riwayat`.
2. Three newly added C3-B CSS variables were undefined; replaced with the existing C1 design-token
   authority.

These fixes were covered before the final canonical verification.

## Tests

New source contract:

`tests/test_c3b_sales_facts_checkout.py`

New transactional SQL regression:

`supabase/tests/c3b_sales_facts_checkout_test.sql`

Migration/test history guard now includes C3-B.

Targeted regression after hardening:

- C3-A/C3-B/POS/UAT targeted: PASS;
- broader C2/C3 targeted suite: PASS;
- C3-B contract: **8/8 PASS**.

## Canonical verification

Before this checkpoint document:

- repository guard: PASS;
- format: PASS;
- lint: PASS;
- TypeScript typecheck: PASS;
- JavaScript: **96/96 PASS**;
- Python: **241/241 PASS**;
- production build: PASS;
- `git diff --check`: PASS.

A final canonical verification is required again after checkpoint documentation before commit/push.

## Persistent database / deployment impact

**NONE.**

- C2/C3 migrations remain unapplied persistently;
- hosted schema is unchanged;
- hosted business data is unchanged;
- RC1 remains immutable;
- RC1 Cloudflare Preview remains unchanged;
- no RC2 Preview exists yet;
- Production remains unchanged;
- automatic Production deployment remains disabled.

## Current C3 status

Phase C3 — Board 02 Sales convergence is now at a safe source checkpoint:

```
C3-A
Product/Variant frontend contract
        +
C3-B
discount/tender/change/line-note/success/history facts
        =
Board 02 sale flow source convergence
```

The remaining final fidelity work should be validated visually later through RC2 Human UAT rather
than inventing another parallel sales engine.

## Next safe phase

**C4 — Board 01 Dashboard convergence.**

Replace the engineering-oriented Home surface with the approved role-aware presentation:

### Owner

- Penjualan Hari Ini;
- Transaksi;
- Kas Tersedia;
- QRIS Belum Cair;
- sales trend/read model;
- best sellers;
- actionable Attention entry points.

### Kasir

- active shift;
- shift cash facts;
- `Jual Sekarang`;
- quick operational actions;
- Owner message;
- actionable Attention entry point.

The dashboard must read existing authorities. It must not create duplicate sale, stock, finance,
shift, or attention writers.

Persistent migration/deployment remains gated until the dedicated RC2 promotion phase.
