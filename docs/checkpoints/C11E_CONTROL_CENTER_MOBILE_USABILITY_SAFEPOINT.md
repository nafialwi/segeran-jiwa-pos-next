# C11-E — Control Center & Mobile Usability Safe Point

Date: 2026-09-23

## Why this checkpoint includes a C11-D usability correction

Mobile UAT evidence showed that unbounded entity lists were still rendered with
native HTML select controls. On Android Chrome this opens a full-screen,
platform-styled list that can contain dozens of items, has weak searchability,
breaks Segeran Jiwa visual continuity, and slows repetitive operational work.

The problem is systemic UI ergonomics, not inventory data correctness.

C11-E therefore begins by locking a shared rule:

- native select remains acceptable for small finite enums and short lists;
- unbounded business entities use a searchable in-app picker;
- the picker must remain keyboard/Escape accessible and mobile bottom-sheet based;
- no picker may change the underlying ID/value authority.

## Mobile long-list correction

A shared SearchablePicker component now provides:

- in-app search;
- selected-item summary;
- accessible dialog/listbox semantics;
- mobile bottom sheet and centered desktop dialog;
- background scroll lock;
- empty state and result count;
- canonical Segeran Jiwa icons.

It is applied to the currently identified unbounded lists in:

- Stock Control: restock item, transfer item, adjustment item;
- Stock Count: searchable checkbox list;
- Sales: Kasbon customer;
- Purchase: supplier, stock item, receivable purchase order;
- Product / Recipe: BOM component;
- Finance: customer debt, supplier payable, employee Kasbon.

Short enumerations such as payment method, adjustment type, role override, and
short location lists intentionally remain native selects.

## C11-E visual convergence

Refinement 04 is converged at source level across:

- Control Center / Settings;
- Appearance & Dashboard preferences;
- Owner Finance;
- Users & Permissions;
- Active Devices;
- Attention;
- Backup & Restore evidence;
- System Health;
- Offline & Sync;
- Diagnostics.

Notable changes:

- Control Center is grouped into Bisnis, Orang, and Sistem for faster scanning;
- horizontal operational/control navigation auto-centers the active route;
- Finance exposes six authoritative summary cards from finance_owner_overview;
- Finance long debt/payable/employee lists use searchable pickers;
- Users supports search, honest loading skeletons, clearer identity/status cards;
- Device lists load independently after a user is selected;
- Attention, Backup, Health, Offline, and Diagnostics use consistent evidence/status visuals;
- mobile layouts use 2-column cards where readable and collapse further at <=360 px.

## Truth & authority preserved

No migration, schema, RPC definition, permission, financial writer, inventory
writer, shift writer, sales writer, identity-admin contract, device-admin
contract, backup procedure, offline mutation policy, or backend health
definition was changed.

Finance summary values are derived only from the existing authoritative
finance_owner_overview response and known account codes:

- KAS_UTAMA;
- KAS_SHIFT;
- BANK;
- QRIS_BELUM_CAIR;
- customer debt balances;
- supplier payable balances.

Backup remains checkpoint evidence, not fake realtime health.
Offline-sensitive mutations remain fail-closed and are not queued.
Diagnostics still never displays credentials.

## Verification

Focused C11-E / C11-D mobile picker / C6 / finance tests: PASS.

Canonical verification after source convergence:

- JavaScript: 96/96 PASS;
- Python: 329/329 PASS;
- repository guard: PASS;
- Prettier: PASS;
- ESLint: PASS;
- TypeScript: PASS;
- production build: PASS;
- git diff-check: PASS.

A final canonical verify is rerun after checkpoint documentation before commit.

## Release status

C11-E is a development safe point only.

RC4 remains immutable as the last accepted UAT release candidate.
Production automatic deployment remains disabled.
The next phase is C11-F mobile/desktop final QA, authenticated timing, visual
regression, then RC5 candidate creation.
