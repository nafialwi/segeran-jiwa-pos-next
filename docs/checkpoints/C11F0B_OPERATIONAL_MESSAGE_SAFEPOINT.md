# C11-F0B — Operational Message Safe Point

Date: 2026-09-23

## Scope

C11-F0B closes the known Refinement 01 gap where the Cashier Dashboard showed
a placeholder for an Owner instruction but no real authority or delivery path
existed.

The implemented capability is intentionally a narrow operational instruction
channel. It is not a general chat system.

## Management capability

A new permission is introduced:

- OPERATIONAL_MESSAGE_MANAGE — Kelola Pesan Operasional

Owner continues to inherit active permissions through the existing authority
model. A non-owner staff member can later be granted this permission through
the existing per-user permission override system without rewriting the feature.

Authorized management can:

- write a title and instruction body;
- mark priority as Normal or Important;
- target all cashiers or one specific active non-owner user;
- define start and expiry times;
- keep validity to a maximum of 30 days;
- review recent messages and read acknowledgement counts;
- cancel an active message.

This checkpoint intentionally does not invent outlet/location targeting because
the current identity model has no persistent staff-to-location assignment
authority suitable for targeting an instruction safely.

## Cashier delivery

The old Dashboard Cashier placeholder is replaced by a real inbox.

The Dashboard:

- loads up to three active targeted messages independently from the main shift
  dashboard, so message loading does not block the operational first paint;
- shows author, title, instruction, priority, and expiry;
- allows the recipient to acknowledge with "Sudah Dibaca";
- keeps the acknowledgement server-validated and idempotent;
- shows a truthful empty state when no current instruction targets the cashier.

All-cashier messages are delivered only to the KASIR role. Individually
targeted messages are delivered only to the target profile.

## Data authority and security

Migration source:

supabase/migrations/20260923133000_c11f0b_operational_message.sql

New tables:

- public.operational_messages
- public.operational_message_reads

Both tables:

- have RLS enabled;
- have all direct grants revoked from public, anon, authenticated, and
  service_role;
- are accessed by the application only through authenticated RPC authority.

Management create/cancel commands:

- require OPERATIONAL_MESSAGE_MANAGE;
- use the existing operation receipt/idempotency mechanism;
- record audit events;
- use SECURITY DEFINER with an empty pinned search_path.

Read acknowledgement is target-validated server-side and records an audit event
the first time the message is acknowledged.

No sale, inventory, finance, production, shift, product, or historical
transaction authority is modified by this phase.

## RPC surface

- operational_message_capability()
- operational_message_options()
- create_operational_message(...)
- cancel_operational_message(...)
- my_operational_messages(...)
- mark_operational_message_read(...)
- manage_operational_messages(...)

The frontend uses these RPCs only. It does not perform direct table DML or
direct message-table reads.

## Compatibility and fail-closed behavior

The migration is committed as source but is NOT applied to Production at this
checkpoint.

A preview connected to the current unmigrated backend therefore remains safe:

- management capability probe returns unavailable when the RPC does not exist;
- the management screen does not expose a working mutation editor;
- the Cashier Dashboard receives an empty operational-message inbox rather than
  claiming a message exists;
- no fallback direct-table write/read path exists.

Hosted end-to-end delivery must be tested only after this migration is applied
to the controlled RC/UAT backend. It is not claimed as tested at this source
safe point.

## UX

Management receives a mobile-first "Instruksi Kasir" screen with:

- compact instruction composer;
- searchable specific-cashier picker;
- validity controls;
- recent-message cards;
- important-message emphasis;
- read progress;
- cancel action.

Dashboard Cashier receives readable instruction cards and acknowledgement
buttons without turning the dashboard into a chat timeline.

## Verification

Focused C11-F0B plus adjacent C11-F0A/C11-E/C11-D tests: PASS.

Canonical verification:

- JavaScript: **96/96 PASS**;
- Python: **348/348 PASS**;
- repository guard: PASS;
- Prettier: PASS;
- ESLint: PASS;
- TypeScript: PASS;
- production build: PASS;
- git diff-check: PASS.

The canonical verification is rerun after checkpoint documentation before the
safe commit.

## Release status

C11-F0B is a source safe point only.

RC4 remains immutable as the last accepted UAT release candidate.
Production automatic deployment remains disabled.
No C11-F0A or C11-F0B migration has been applied to Production.

Next: C11-F0C — Shift Packaging Reconciliation.
