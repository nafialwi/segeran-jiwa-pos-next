# C11-F0E — Shift State & Mobile Interaction Safe Point

Date: 2026-09-23

## Scope

C11-F0E closes the remaining day-to-day Shift interaction residue reported during Legacy/UAT comparison without changing shift, reconciliation, inventory, or packaging authority.

The focus is practical cashier behavior on touch devices:

- stale numeric values after closing and reopening a shift;
- physical cash being shown as zero before it is actually counted;
- native blocking alerts after shift close;
- lingering form drafts across shift boundaries;
- mobile tap/highlight residue on Shift controls.

## Shift closing input truth

Uang Aktual di Laci is now a fresh physical input for every closing attempt. The field begins empty; the summary shows Belum diisi until a real value is entered; variance shows — until valid; closing requires a non-negative physical cash value; backend close authority remains closeShift(shift.id, actualCash).

## Cross-shift reset

Opening/closing transitions clear transient UI drafts that must not leak into a new operational context: opening balance, physical closing cash, expense drafts/messages, packaging message, and shift-level feedback.

## Non-blocking result feedback

The native blocking alert() used after shift closing has been removed. Successful opening and closing now use inline status feedback.

## Packaging gate remains unchanged

Packaging Closing remains visible and recommended, but shift closing is not hard-blocked by packagingClosingComplete. The only new closing UI gate is a real physical-cash input plus existing reconciliation readiness.

## Touch behavior

Shift interactive controls now use touch-action: manipulation, transparent webkit tap highlight, and no hover transform on coarse/no-hover pointers.

## Authority invariants

Unchanged: Shift open/close server authority, shift reconciliation RPC, packaging reconciliation RPC, inventory count/post authority, no direct frontend update to public.shifts, and no new database writer or migration.

## Verification

Focused C11-F0C + C11-F0E tests: 16/16 PASS. Canonical verification: **96/96 JavaScript + 375/375 Python PASS**, plus repo guard, format, lint, TypeScript, production build, and diff-check PASS.

## Release status

C11-F0E is a source safe point. RC4 remains immutable. Production automatic deployment remains disabled. No C11 frontend source is released to Production by this checkpoint.

Next: C11-F — final responsive matrix, full regression, UAT-preview gate, and complete Owner/Kasir operating guide.
