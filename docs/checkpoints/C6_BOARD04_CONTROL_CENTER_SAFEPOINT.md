# C6 Board 04 Control Center Convergence — SAFEPOINT

Date: 2026-09-22

Branch: work/cs06743-patch3-hardening

## Outcome

C6 converges the approved Board 04 Control Center around existing authorities and explicit evidence.

The application now has a canonical Settings Home / Pusat Kontrol with entry points for:

- Tampilan & Dashboard;
- Keuangan;
- Pengguna & Izin;
- Perangkat Aktif;
- Perhatian;
- Backup & Restore;
- Kesehatan Sistem;
- Offline & Sync;
- Diagnostik.

C6 does not create a new inventory, finance, authentication, backup, or synchronization engine.

This checkpoint is source-only. No post-RC1 C2/C3 migration is applied persistently and no new
Cloudflare Preview is created.

## Baseline preserved

C6 started from C5-B safe point:

- commit: ff62f3a0dd8e55178bce1ff47f513799ab8c4e8d
- branch: work/cs06743-patch3-hardening
- immutable RC1: uat-rc-20260921-1 -> e844f9b9ad07ca240e1ba4f72a39c6c7aefbb489
- Production automatic deployment: DISABLED

## Control Center

New route:

/pengaturan

New screen:

src/screens/ControlCenterScreen.tsx

The Control Center does not duplicate existing feature engines.

Owner links reuse existing authorities:

- Keuangan -> /keuangan
- Pengguna & Izin -> /pengguna#permissions
- Perangkat Aktif -> /pengguna#devices
- Backup & Restore -> /pengaturan/backup

Shared/read-only control surfaces include:

- Perhatian;
- Kesehatan Sistem;
- Offline & Sync;
- Diagnostik.

The Control Center itself and noncritical appearance settings use SETTINGS_NONCRITICAL.
Owner-only business/security surfaces remain Owner-only.

## Appearance / dashboard preferences

New route:

/pengaturan/tampilan

Preferences are deliberately noncritical and device-local:

- Nyaman / Ringkas density;
- Normal / Teks Besar font scale.

Storage key:

sjpos.control.preferences.v1

The preferences are applied to document-level data attributes and affect the shared visual system.

They do not change:

- price;
- sale;
- stock;
- money;
- permission;
- audit;
- backend business configuration.

Therefore no new server writer or audit-sensitive setting channel is invented.

## Backend health evidence

New live evidence function:

probeBackendAuthority()

The probe executes the existing server authority RPC:

get_my_authority

It records:

- PASS / FAIL;
- checked timestamp;
- measured round-trip latency;
- response detail.

The backend probe source is intentionally separated from browser connectivity source.

navigator.onLine is not used by the Backend Authority probe.

A PASS means only:

- the backend answered at that moment;
- the active session authority contract could be parsed.

It does not claim that every database table, backup, network path, or business feature is healthy.

## Connectivity evidence

Browser connectivity lives in a separate source:

src/control/connectivity.ts

It reports only ONLINE / OFFLINE device connectivity.

UI copy explicitly states that this is not backend-health evidence.

This preserves the P5A locked contract.

## System Health

New route:

/pengaturan/kesehatan

The screen separates evidence types:

1. Koneksi Perangkat
   - browser connectivity only.

2. Backend Authority
   - live get_my_authority server probe.

3. Backup / Restore
   - last verified P5C checkpoint evidence, clearly timestamped.

No status is turned green simply because the browser is online.

## Backup & Restore

New route:

/pengaturan/backup

Owner-only.

C6 does not place backup payloads or credentials in source.

The screen uses a metadata-only checkpoint evidence record derived from the locked P5C evidence:

- evidence kind: VERIFIED_CHECKPOINT;
- P5C restore verification date: 2026-09-21;
- checkpoint backup gate: HEALTHY;
- isolated restore: PASS;
- method: isolated PostgreSQL 18.6 restore;
- archive TOC entries: 1210.

The screen explicitly states:

- this is the last verified checkpoint evidence;
- this is not realtime backup health;
- it does not prove a newer backup exists.

C6 also intentionally does not provide a direct Production restore button.

Restore remains a high-risk operator/runbook procedure.

## Actionable Attention

The existing Perhatian page is upgraded from connectivity-only presentation into an
evidence-bounded action center.

It can now surface:

- device offline;
- failed live Backend Authority probe;
- stale backup checkpoint evidence for Owner when the last evidence is older than the bounded
  attention threshold.

Actions deep-link to:

- Offline & Sync;
- Kesehatan Sistem;
- Backup & Restore.

When the available checks do not require attention, the screen says only that no active attention
was found from the available checks.

It explicitly states:

Tidak berarti seluruh sistem sehat.

The Attention page remains read-only and does not mutate business facts.

## Offline & Sync

New route:

/pengaturan/offline-sync

The screen makes the P5B behavior visible to users:

- Tidak ada antrean mutasi offline;
- operasi server tetap online-only;
- browser connectivity is not backend status.

C6 does not add an offline mutation queue.

## Diagnostics

New route:

/pengaturan/diagnostik

The screen exposes safe runtime evidence:

- Backend probe result / latency;
- device connectivity;
- Role;
- masked Device ID;
- application build mode;
- masked active session ID.

It explicitly does not expose:

- access token;
- refresh token;
- password;
- service-role key;
- database connection string;
- database credentials.

## Existing Users / Permissions / Devices authority

C6 does not replace OwnerUsersScreen or its admin Edge Functions.

Existing authorities remain:

- owner_list_users;
- owner_list_devices;
- identity-admin;
- device-admin.

The existing Permission and Device sections now have stable anchors:

- #permissions
- #devices

so Control Center cards can deep-link to the real existing authority screen.

## Finance authority

Control Center links Owner to the existing Finance screen.

No Owner-global finance information is exposed to Cashier through C6.

No second money writer is introduced.

## Icon fidelity

The runtime icon subset did not yet contain the approved appearance.png or active-device.png assets.

C6 therefore does not invent files or silently claim those assets exist.

It uses existing consistent registered semantic fallbacks:

- settings for Tampilan & Dashboard;
- security-sync for Perangkat Aktif.

This follows the locked rule that missing semantics may use one consistent fallback until the
approved custom asset is actually ingested.

## UI / UX convergence

C6 adds the shared Board 04 presentation language:

- Control Center cards;
- evidence cards;
- status source labels;
- preference choice cards;
- Health evidence grid;
- diagnostics cards;
- truth / limitation notices;
- responsive mobile / tablet / desktop layouts.

The design continues to use the C1 design system and existing Segeran Jiwa runtime icon registry.

## Error-prevention / implementation hardening

C6 was implemented in small bounded jobs.

During implementation:

1. one connector-command composition attempt failed before enqueue because a nested template literal
   conflicted with the wrapper string; no repository file was changed by that attempt;

2. a formatting job stopped because Prettier was accidentally invoked on a Python test file; source
   changes preceding that formatting call were preserved and then verified separately;

3. a targeted npm test invocation passed the JavaScript suite but forwarded test-selection
   arguments into Python discovery; this was a command-shape issue, not a product regression, and was
   rerun with direct vitest invocation;

4. TypeScript then identified a missing SystemHealthScreen import and two icon names whose binary
   assets were not in the runtime registry. The import was corrected and the missing icon names were
   replaced with existing registered fallbacks rather than fabricating assets.

Each issue was resolved before canonical verification.

## New source files

- src/control/backup-evidence.ts
- src/control/connectivity.ts
- src/control/control-center-api.ts
- src/control/preferences.ts
- src/screens/AppearanceSettingsScreen.tsx
- src/screens/BackupRestoreScreen.tsx
- src/screens/ControlCenterScreen.tsx
- src/screens/DiagnosticsScreen.tsx
- src/screens/OfflineSyncScreen.tsx
- src/screens/SystemHealthScreen.tsx
- tests/test_c6_control_center_convergence.py

## Converged existing source

- src/App.tsx
- src/app.css
- src/auth/permission.ts
- src/components/AppShell.tsx
- src/screens/AttentionScreen.tsx
- src/screens/MenuScreen.tsx
- src/screens/OwnerUsersScreen.tsx

## Verification before checkpoint documentation

Focused C6 contract:

- 11/11 PASS.

Related Python regression:

- P5A;
- P5B;
- C4;
- C5-B;
- C6;
- 36/36 PASS.

Correctly invoked targeted JavaScript regression:

- operational-health;
- online-action;
- C1 AppShell;
- 10/10 PASS.

Canonical verification before checkpoint documentation:

- repository guard: PASS;
- formatting: PASS;
- lint: PASS;
- TypeScript: PASS;
- JavaScript: 96/96 PASS;
- Python: 280/280 PASS;
- production build: PASS;
- git diff --check: PASS.

A final canonical verification is required again after this checkpoint document and project-state
update before commit/push.

## Persistent database / deployment impact

NONE.

C6 adds no database migration.

- hosted schema unchanged;
- hosted business data unchanged;
- C2/C3 post-RC1 migrations remain unapplied persistently;
- RC1 remains immutable;
- RC1 Preview remains unchanged;
- no RC2 Preview exists yet;
- Production remains unchanged;
- automatic Production deployment remains disabled.

## Convergence status after C6

Source convergence now covers:

C1 AppShell / icons +
C2 Product / Variant / execution / readers +
C3 Board 02 Sales +
C4 Board 01 Dashboards +
C5 Board 03 Operations +
C6 Board 04 Control Center

## Next safe phase

C7 — Secondary Screen Convergence.

Bring the remaining functionally-correct but visually older surfaces into the shared product
language without replacing their engines:

- Finance;
- Reports;
- Transaction History detail / Refund / Correction presentation;
- Handover;
- Shift History / Reconciliation residual presentation;
- Owner Users / Permissions detail layout;
- Expense Approval;
- Legacy migration utility where appropriate.

After C7, proceed to C8 full cross-domain regression before creating RC2.
