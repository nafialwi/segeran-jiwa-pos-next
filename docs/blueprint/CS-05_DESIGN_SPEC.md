# CS-05 DESIGN SPEC — Shift, Cash, Handover & Reconciliation

## Scope

Bucket weight: 10% (from ROADMAP_PROGRESS.md)

Dependencies: CS-03 (Identity/Permission) — specifically CR-CS03-01 (sale requires actor Shift Aktual) dan CR-CS03-02 (Shift ownership immutable).

## Business Rules

### R-01: Shift Lifecycle

1. **Open**: User membuka shift → sistem snapshot konfigurasi saat itu (CR-CS03-02)
2. **Active**: Shift berjalan, semua transaksi terikat ke shift ini
3. **Close**: User menutup shift → sistem hitung reconciliation
4. **Handover**: User A close shift → User B open shift baru (atomic operation)

### R-02: Shift Ownership Immutability

- Setelah shift dibuka, `actor_id` tidak boleh berubah (CR-CS03-02)
- Konfigurasi shift di-snapshot saat open (tidak terpengaruh perubahan settings nanti)
- Historical shifts tetap reproducible setelah setting changes

### R-03: Sale Requires Active Shift

- Setiap completed sale wajib terikat ke Shift Aktual milik aktor (CR-CS03-01)
- Owner tidak bypass shift requirement (no parallel Owner-sale path)
- Failed/missing shift binding → fail closed (bukan invent shift)

### R-04: Cash Reconciliation

- Setiap shift close → hitung:
  - Expected cash (sum of cash payments in shift)
  - Actual cash (manual input by user)
  - Variance (actual - expected)
- Variance != 0 → flag untuk audit (tidak block close, tapi tercatat)

### R-05: Handover Protocol

1. Outgoing user: close shift (reconciliation)
2. System: validate no pending transactions
3. Incoming user: open new shift
4. Atomic: jika step 3 gagal, step 1 di-rollback

## Data Model (Conceptual)

### Table: shifts

- `id` (UUID, PK)
- `actor_id` (FK users.id, immutable after open)
- `opened_at` (timestamp)
- `closed_at` (timestamp, nullable)
- `config_snapshot` (JSONB — settings saat open)
- `status` (OPEN | CLOSED | HANDOVER_PENDING)
- `expected_cash` (numeric, calculated on close)
- `actual_cash` (numeric, input on close, nullable)
- `variance` (numeric, calculated: actual - expected)

### Table: cash_transactions

- `id` (UUID, PK)
- `shift_id` (FK shifts.id)
- `sale_id` (FK sales.id, nullable for manual adjustments)
- `amount` (numeric)
- `type` (SALE | REFUND | ADJUSTMENT)
- `created_at` (timestamp)

### Table: handovers

- `id` (UUID, PK)
- `outgoing_shift_id` (FK shifts.id)
- `incoming_shift_id` (FK shifts.id)
- `handover_at` (timestamp)
- `notes` (text, nullable)

## Acceptance Criteria

### AC-01: Shift Open

- User dengan permission `shift.open` bisa buka shift
- Config snapshot tercatat (tidak berubah meski settings berubah nanti)
- Tidak bisa buka shift jika user sudah punya shift OPEN

### AC-02: Sale Binding

- Sale tanpa active shift → rejected (fail closed)
- Sale tercatat dengan `shift_id` yang benar
- Query `sales_by_shift` returns correct aggregation

### AC-03: Shift Close

- User dengan permission `shift.close` bisa close shift miliknya
- Expected cash calculated dari sum(cash_transactions.amount where type=SALE)
- Actual cash input manual (required)
- Variance calculated dan tercatat

### AC-04: Handover

- Outgoing user close shift → incoming user open shift (atomic)
- Jika incoming open gagal, outgoing close di-rollback
- Handover record created linking both shifts

### AC-05: Shift Ownership

- User A tidak bisa close shift milik User B (kecuali Owner audit permission — future)
- Shift history immutable (tidak ada UPDATE pada closed shifts)

## Migration Strategy

### Phase 1: Schema (CS-05-P1)

- Create table `shifts` dengan constraints
- Create table `cash_transactions`
- Create table `handovers`
- Create indexes untuk query performance
- Register migration di registry (seperti CS-04)

### Phase 2: Backend Logic (CS-05-P2)

- API: `POST /shifts/open`
- API: `POST /shifts/close`
- API: `POST /handovers`
- Middleware: validate active shift untuk sale endpoints

### Phase 3: UI (CS-05-P3)

- Screen: Shift Management (open/close)
- Screen: Handover (select incoming user)
- Screen: Shift History (read-only)
- Integration: Sale flow require shift selection

### Phase 4: Reports (CS-05-P4)

- Report: Daily Shift Summary (by actor)
- Report: Cash Variance Analysis
- Report: Handover Audit Trail

## Testing Strategy

### Unit Tests (Python)

- `test_shift_lifecycle.py`: open → transactions → close → variance
- `test_shift_ownership.py`: immutability checks
- `test_handover_atomicity.py`: rollback scenarios

### Integration Tests (SQL)

- `010_cs05_shifts.sql`: migration + regression tests
- Test: sale without shift → rejected
- Test: close shift with pending transactions → handled

### Manual QA

- Open shift → make sales → close shift → verify variance
- Handover between two users → verify atomic
- Attempt to modify closed shift → rejected

## Risks & Mitigations

### Risk-01: Orphan Shifts

**Problem**: Shift opened but never closed (app crash, user forget)
**Mitigation**: 
- Daily cron: flag shifts OPEN > 24h as STALE
- Admin UI: force close stale shifts (with audit log)

### Risk-02: Cash Variance Abuse

**Problem**: User consistently reports high variance (theft indicator)
**Mitigation**:
- Alert system: variance > threshold → notify Owner
- Audit report: variance trend by actor

### Risk-03: Handover Race Condition

**Problem**: Two users attempt handover simultaneously
**Mitigation**:
- Database constraint: unique(shift_id) where status=OPEN
- Application-level lock during handover

## Compliance with CS-03 CRs

✅ **CR-CS03-01**: Every sale bound to actor's active shift (R-03)
✅ **CR-CS03-02**: Shift ownership immutable (R-02), config snapshot at open (R-01)

## Next Steps

1. **CS-05-P0** (this document): Design spec — DONE
2. **CS-05-P1**: Migration schema + regression SQL
3. **CS-05-P2**: Backend APIs + middleware
4. **CS-05-P3**: UI screens
5. **CS-05-P4**: Reports

## References

- Blueprint: `docs/blueprint/15_WORKFLOW_PROFILE.md`
- CS-03 CRs: `docs/decisions/CS-03_CR_SUPPLEMENT.md`
- Roadmap: `docs/checkpoints/ROADMAP_PROGRESS.md`
- CS-04 Lock: `docs/checkpoints/CS-04_CHECKPOINT_REPORT.md`
