# CS-03 Approved CR Supplement

## CR-CS03-01 — Sale requires actor Shift Aktual

Every completed sale, including a sale performed by Owner, must be bound to the active Shift Aktual owned by the actor who performs that sale.

Impact:

- UI: future Jual flow must require/resolve the actor's active shift.
- Permission: Owner does not bypass the shift requirement merely because Owner has higher authority.
- Database: future sales facts require actor profile + actual shift references.
- Keuangan/Laporan: projections read the same sale/shift facts; no parallel Owner-sale path.
- Offline: future offline sale design must preserve the same actor/shift precondition.
- Migration: no Shift table is introduced by CS-03.
- Recovery: failed/missing shift binding must fail closed rather than invent a shift.
- Acceptance: no completed sale exists without an actor-owned active shift.

## CR-CS03-02 — Actual Shift ownership and configuration snapshot

Shift Aktual ownership is immutable after opening. The configuration used at open is snapshotted into the actual shift. Changing shift settings affects subsequent actual shifts only. Handover closes the outgoing user's shift and opens a new shift for the incoming user.

Impact:

- UI: settings manage current shift configuration; operational history shows actual values.
- Permission: a user may continue only their own active shift unless future Owner audit permission explicitly allows read-only inspection.
- Database: future Shift tables preserve actor ownership and configuration snapshot.
- Keuangan/Laporan: historical shifts remain reproducible after later setting changes.
- Offline: no offline ownership reassignment.
- Migration: no Shift table is introduced by CS-03.
- Recovery: handover never rewrites the owner of an existing shift.
- Acceptance: shift ownership never changes in place.
