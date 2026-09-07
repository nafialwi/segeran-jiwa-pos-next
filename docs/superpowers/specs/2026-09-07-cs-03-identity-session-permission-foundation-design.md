# CS-03 — Identity, Session & Permission Foundation — Design Spec

**Project:** Segeran Jiwa POS Next  
**Date:** 2026-09-07  
**Status:** DESIGN APPROVED IN CHAT — implementation not yet approved  
**Blueprint baseline:** v1.0 FINAL LOCK  
**Schema version entering CS-03:** 1  
**Canonical main baseline for this design package:** `498a01968e11f320622cefa822c591e3018f20e4`  
**Current whole-project progress before CS-03 implementation:** 32.0%

---

## 1. Purpose

CS-03 establishes the authentication, session, device, user-status, and permission authority required by every later business module. It must make identity and authorization reliable before Penjualan, Shift & Kas, Persediaan, Pembelian, Produksi, Keuangan, and Laporan begin depending on them.

CS-03 is a foundation milestone. It does not implement the full business modules that will consume this authority.

Success means the system can answer, server-side and fail-closed:

1. Who is this user?
2. Is the account currently active?
3. Is this session/device still allowed?
4. Is the user a current member of this business?
5. What permission is effective now?
6. Is the requested resource inside the user's allowed scope?

Frontend visibility is only a UX projection of this authority and is never the security boundary.

---

## 2. Locked Product Decisions Carried Into CS-03

### 2.1 Owner and roles

- `Owner` is the highest administrator and business authority.
- There is no separate product role named `Admin`; operational references to “admin” mean Owner.
- The first built-in operational preset is `Kasir`.
- The permission engine is generic enough for future presets such as Gudang or Delivery without rebuilding authorization.
- Initial operation is expected to have one Owner and three Kasir accounts, but the data model must not hard-limit the count to three.

### 2.2 Username and password

- User-facing login uses **username + password**.
- Username is chosen by Owner and becomes permanent after account creation.
- Display name is editable independently from username.
- Username is never reused for a different person after that account has existed.
- There is no public self-signup.
- The first Owner account is provisioned once through Supabase during initial setup.
- Subsequent staff accounts are created by Owner from the application.
- Kasir cannot change their own password in the application.
- Owner can reset staff passwords.
- Exceptional username maintenance may be performed directly in Supabase outside the normal application flow, with coordinated identity/profile updates and audit awareness.

### 2.3 Persistent login

- First login requires normal authentication.
- A successful device can be remembered so the user does not need to log in whenever the app/PWA is reopened.
- Persistent login never overrides current account status, permission, membership, or device/session revocation.

### 2.4 Shared devices

- Personal devices and shared devices are both supported.
- One shared device has only one active application user at a time.
- `Ganti Pengguna` requires the incoming user's password.
- Switching user removes the outgoing local session from that device but does not close that user's active business shift.
- A device may remember previously used usernames for convenience, but must not retain staff passwords or multiple simultaneously usable refresh-token sessions.

### 2.5 User status

User status values remain:

- `ACTIVE`
- `LEAVE`
- `DISABLED`

Rules:

- `ACTIVE`: may authenticate and operate according to effective permission.
- `LEAVE`: account/history remain, all active sessions are revoked, and business access is blocked until Owner reactivates the account.
- `DISABLED`: all active sessions are revoked and business access is blocked until Owner explicitly reactivates the account.
- Re-activation requires one fresh login before the device can become remembered again.
- Application UI does not hard-delete users because historical transactions, shifts, and audit events must keep an immutable actor reference.

### 2.6 Permission model

Authorization uses **Preset + Per-user Override**:

`effective permission = preset baseline + explicit user override`, subject to permanent hard boundaries.

Permission changes take effect without requiring the user to log out and back in. Protected server-side operations must evaluate current authority rather than trusting stale UI state or stale authorization claims.

### 2.7 Kasir scope

Kasir default authority includes:

- sell when an active shift exists and selling is permitted;
- open/close own shift when permitted;
- view own active shift and own shift summary/history;
- use enabled/allowed payment methods;
- view expenses belonging to the Kasir's own shift;
- optionally **Catat Pengeluaran Shift** when explicitly allowed.

Kasir is denied:

- another user's shift;
- another user's shift transactions/history;
- global business finance;
- Bank balances;
- global profit;
- Capital;
- Owner personal withdrawal/expense;
- global supplier debt;
- month close;
- user/device/security administration.

Kasir does not receive `Riwayat Semua` even if that capability exists for future non-Kasir operational roles.

### 2.8 Reports

Owner may grant selected **operational reports** through settings/permissions, such as inventory, purchasing, production, or bounded sales/shift reports appropriate to that role.

The following remain Owner-only hard boundaries:

- Laporan Keuangan;
- global profit;
- capital;
- Bank balances;
- global reconciliation;
- Tutup Bulan.

### 2.9 Shift-linked selling

Approved business-rule refinement:

> Every completed sale, including a sale performed by Owner, must belong to the active actual shift of the user performing the sale.

Owner therefore has management capabilities and may also perform sales, but Owner is not exempt from shift discipline when acting as a seller.

### 2.10 Actual shift semantics

Approved business-rule refinement:

- Owner configures shift count, name, and recommended hours in Settings.
- Opening work creates an **Actual Shift** (`Shift Aktual`) owned by one user.
- The Actual Shift stores a snapshot of relevant shift configuration at opening time so later Settings changes do not rewrite history.
- Recommended shift hours are guidance, not a hard time lock.
- One user may have at most one active Actual Shift at a time.
- Different users, including Owner, may have active shifts concurrently.
- Shift ownership is immutable.
- An active shift follows the user, not a particular device.
- A trusted-device change or `Ganti Pengguna` does not automatically close the user's shift.
- If ownership must change, the current user closes their shift and the next user opens a new Actual Shift through the explicit handover flow.

Full Shift & Kas persistence is outside CS-03. CS-03 must expose identity/session/permission interfaces that allow these rules to be enforced later without redesigning authentication.

### 2.11 Shift expense semantics

Permission label is **Catat Pengeluaran Shift**, not generic “Pengeluaran”.

A shift expense recorded by Kasir is one business fact. It is visible:

- to that Kasir within the Kasir's own shift context; and
- to Owner in the consolidated business expense/finance/report projections.

It is not duplicated into a separate Owner transaction.

Each future shift-expense fact must retain at least amount, category, description, timestamp, actor, actual shift, funding account/source, and approval state where applicable.

---

## 3. Scope

### 3.1 In CS-03

- Supabase Auth integration for user identity and password authentication.
- Username authority and normalized username uniqueness.
- Binding Supabase Auth users to application profiles.
- First-Owner bootstrap contract.
- Owner-controlled staff creation/reset workflow architecture.
- User status enforcement.
- Preset permissions and per-user overrides.
- Permanent Owner-only hard boundaries.
- Persistent session behavior.
- Trusted/shared device registry.
- Device/session revocation and removal-from-active-list semantics.
- `Ganti Pengguna` session isolation.
- Route/menu permission projection.
- Server-side/RLS/RPC authorization primitives for later domain commands.
- Auditability of identity/security changes.
- Negative-security test coverage.
- Verification of the current `private.schema_versions` access boundary as a negative-security item, without automatic DDL remediation unless evidence shows it is exposed.

### 3.2 Explicitly not in CS-03

- Product catalog and full Penjualan UI.
- Sales ledger/business transaction implementation.
- Full Shift & Kas tables/flows.
- Full inventory flows.
- Purchasing, production, customer debt, employee advances.
- Full business finance/report implementation.
- Offline cash-sale implementation.
- APK wrapping.
- Multi-tenant/SaaS behavior.

CS-03 may define interfaces and future foreign-key expectations for these modules, but must not implement their business facts early.

---

## 4. Architecture

### 4.1 Authority layers

```text
Supabase Auth
  identity + password + auth session
        ↓
Application Identity
  profile + username + business membership + status
        ↓
Authorization Authority
  role preset + user override + hard boundary
        ↓
Session / Device Governance
  app device identity + auth session mapping + revocation state
        ↓
Domain Command Guard
  current user + current permission + resource scope
        ↓
Business module
  Sale / Shift / Inventory / Purchase / Finance / Report
```

Each layer has one responsibility and may change internally without forcing consumers to bypass its public interface.

### 4.2 Existing CS-02 authority reused

CS-03 must build on, not replace:

- `auth.users`
- `public.profiles`
- `public.access_roles`
- `public.business_memberships`
- CS-02 RLS/grant skeleton
- operation/audit foundations established by CS-02

No second user table may become identity authority and no parallel authorization engine may be introduced.

---

## 5. Authentication Design

### 5.1 User-facing credential

The UI accepts:

- username
- password

Supabase Auth remains the password-verification system.

Because Supabase Auth does not provide a native username credential, CS-03 uses a deterministic internal Auth identifier derived from normalized username rather than exposing a public lookup endpoint that resolves arbitrary usernames to personal email addresses.

The exact internal identifier format is an implementation detail and must:

- be deterministic from normalized username;
- remain invisible to normal users;
- not contain a real employee email address;
- not create a public enumeration API;
- be validated against the application username authority before account creation.

### 5.2 Username normalization

The design requires one canonical normalization function used by creation and login. At minimum it must define:

- case behavior;
- whitespace trimming/rejection;
- permitted character set;
- uniqueness behavior.

Implementation plan must pin the exact normalization and tests before database migration is approved.

### 5.3 First Owner bootstrap

The first Owner is created once through Supabase's administrative setup path. There is no public “first user becomes Owner” route and no browser-exposed admin secret.

The bootstrap procedure must bind:

`auth user → profile → active business membership → Owner role`

and then close the bootstrap condition so later users cannot claim Owner authority through the same path.

### 5.4 Staff creation/reset

Normal staff lifecycle is Owner-controlled from the application.

Any Auth Admin operation that requires a secret/service credential runs only in a trusted server-side boundary. A secret/service credential must never be bundled into Vite/browser/PWA source.

The trusted server action must independently verify the caller's Owner authority before creating users, resetting passwords, changing account status, or revoking staff access.

---

## 6. Data Authority Proposed for CS-03

The names below are design-level proposed entities. Exact DDL belongs to the implementation plan and requires explicit migration approval.

### 6.1 Username identity

`user_login_identities`

Purpose: immutable application login name bound to one profile.

Conceptual fields:

- `profile_id`
- `username`
- `normalized_username`
- `created_at`

Constraints:

- one login identity per profile for v1;
- normalized username globally unique within this single-business deployment;
- no application-level rename operation;
- no reuse after account history exists.

### 6.2 Permission definitions

`permission_definitions`

Conceptual fields:

- `code`
- `display_name`
- `category`
- `security_class`
- `active`

`security_class` distinguishes normal overridable operational permissions from permanent Owner-only authority.

### 6.3 Preset permission mapping

`role_permissions`

Conceptual fields:

- `role_code`
- `permission_code`
- `allowed`

The initial supported presets are Owner and Kasir. Future Gudang/Delivery presets can be added through the same model.

### 6.4 Per-user override

`user_permission_overrides`

Conceptual fields:

- `profile_id`
- `permission_code`
- `effect` (`ALLOW` or `DENY`)
- `changed_by`
- `changed_at`

Hard Owner-only permissions ignore non-Owner ALLOW overrides.

### 6.5 Device registry

`trusted_devices`

Conceptual fields:

- immutable app-generated `device_id`
- `profile_id` or explicit user-device association
- friendly device name
- device kind (`PERSONAL` / `SHARED`)
- platform/browser/PWA metadata kept coarse and non-invasive
- `created_at`
- `last_seen_at`
- `revoked_at`
- `removed_from_active_list_at`

The application must not depend on IMEI, MAC address, or aggressive browser fingerprinting.

### 6.6 Session registry

`session_registry`

Conceptual fields:

- Supabase Auth `session_id`
- `profile_id`
- `device_id`
- `started_at`
- `last_seen_at`
- `revoked_at`
- revocation reason/actor where applicable

Supabase Auth session data remains the authentication-session source. The application registry adds business device governance and audit semantics; it does not replace Supabase Auth.

---

## 7. Permission Evaluation

### 7.1 Evaluation order

A protected action is allowed only if all checks pass:

```text
JWT/auth identity valid
→ application profile exists
→ profile status = ACTIVE
→ business membership active
→ current session/device allowed
→ effective permission allows action
→ requested resource belongs to allowed scope
→ domain-specific preconditions pass
```

Any failed check is deny-by-default.

### 7.2 Permission freshness

UI may cache permissions for responsive navigation, but business authorization must use current authority.

Permission changes must affect protected operations without a required re-login. Therefore CS-03 must not make long-lived JWT custom claims the sole source of mutable authorization.

### 7.3 Resource scoping

Permission code answers **what** the user may do; resource scope answers **to which facts**.

Example:

- `SHIFT_VIEW_SELF` does not permit reading another user's shift even if a route ID is manually changed.
- Future operational report permission may allow a bounded report while finance tables remain inaccessible.

---

## 8. Permanent Owner-only Boundaries

The following are not ordinary staff toggles:

- create/manage users;
- reset staff password;
- change permission authority;
- change account status;
- revoke devices/sessions for other users;
- business finance full access;
- Bank balances;
- global profit;
- Capital;
- Owner personal withdrawal/expense;
- global reconciliation;
- Tutup Bulan;
- security authority settings;
- audit-integrity settings;
- backup/restore authority;
- high-impact technical correction authority.

The UI must not offer an override that can accidentally elevate a Kasir into these boundaries, and the database/server policy must enforce the same denial.

---

## 9. Persistent Session & Device Governance

### 9.1 Persistent session

After successful login, the browser/PWA stores the normal Supabase client session using supported client storage behavior so the user returns directly to the application while the session remains valid.

A remembered session is accepted only after application authority checks confirm status, membership, permission, and device/session state.

### 9.2 Device identity

On first approved use, the app creates a cryptographically random app `device_id` stored locally and registered server-side after successful authentication.

Friendly device names such as `HP Kasir Gerai`, `Tablet Gerai`, or `Laptop Owner` are application metadata and may be changed without changing the immutable device ID.

### 9.3 Multiple devices

One user may have multiple trusted devices. This supports Owner using phone and laptop or a Kasir continuing work from another approved device.

Each device/session remains independently visible and revocable.

### 9.4 Shared device

On a shared device:

1. outgoing user chooses `Ganti Pengguna`;
2. local outgoing session is removed from that device;
3. the app shows remembered usernames only as convenience labels;
4. incoming user supplies password;
5. a new/current auth session is associated with the same shared device ID;
6. any business shift owned by the outgoing user remains open until explicitly closed through Shift & Kas.

### 9.5 Revoke versus remove

Owner device actions are distinct:

- **Cabut Akses:** make the device/session unusable.
- **Hapus dari Daftar:** remove an already-inactive device from the normal active-management list.
- **Cabut & Hapus:** revoke first, then remove it from normal list.

A currently usable device cannot be removed from the list without first being revoked.

Security data needed to prevent stale-session reuse may remain as a minimal tombstone even after the friendly device record disappears from the normal UI.

### 9.6 User views in Owner UI

Owner management should support two projections:

- by user: status, role/preset, effective permissions, devices/sessions;
- by device: friendly device name, personal/shared type, current/recent user, active/revoked state.

Normal screens prioritize active users/devices so experiments with many browsers do not create permanent clutter.

---

## 10. Revocation Guarantees

Supabase access tokens may remain cryptographically valid until their expiry even after refresh-token/session revocation. Therefore high-value business commands must not assume “JWT signature valid” means “still authorized now.”

For protected commands, CS-03 must use an online current-authority check that can deny:

- revoked session/device;
- LEAVE/DISABLED account;
- removed business membership;
- permission revoked after token issuance.

The implementation plan must choose the least-complex server/RLS/RPC pattern that provides this guarantee without introducing a second authentication system.

---

## 11. Owner Confirmation for Sensitive Actions

Owner login remains persistent.

Selected high-impact actions may require a configurable Owner PIN confirmation layer, for example:

- reset staff password;
- sensitive permission change;
- revoke all sessions;
- restore.

PIN is confirmation only and is never the primary authentication method.

The implementation must not block initial CS-03 completion on every possible sensitive-action PIN screen; it must establish the authority hook so later settings can enable the confirmation consistently.

---

## 12. Route and Menu Guards

The frontend derives visible navigation from effective permission and active feature configuration.

Examples:

- Kasir does not see business finance navigation.
- Future Gudang role can see inventory pages if permitted.
- A hidden route manually entered by URL is still denied server-side if permission/scope does not allow it.

The UI guard and server guard must share permission codes but not share trust assumptions.

---

## 13. Shift Integration Contract for Later Milestone

CS-03 does not create the full Shift schema, but later Shift & Kas must be able to consume these stable identity interfaces:

- `current_profile_id`
- `current_business_id`
- `effective_permissions`
- `current_device_id`
- `current_auth_session_id`

The Shift milestone must enforce:

- one active Actual Shift per user;
- immutable shift owner;
- transaction actor equals the user operating the sale;
- completed sale references that user's active Actual Shift;
- Owner is not exempt when selling;
- user may resume own active shift from another trusted device;
- no user can take ownership of another user's active shift;
- handover closes the old shift and opens a new one;
- shift snapshot preserves configured name/recommended times relevant at open.

These rules are included here as integration requirements, not premature Shift implementation.

---

## 14. Shift Expense Integration Contract for Later Milestone

The later Shift/Expense domain must expose one fact that can be projected differently for Kasir and Owner.

Kasir scope:

- read own shift expenses;
- create shift expense only with `SHIFT_EXPENSE_CREATE` or equivalent approved permission.

Owner scope:

- read consolidated business expense projection;
- see actor, shift, time, category, description, amount, funding source, and approval state.

The same expense record feeds Shift, Cash, Finance, Reports, and Activity; it must not be duplicated into a second Owner expense fact.

---

## 15. Offline Rules

CS-03 authority mutations are online-required:

- initial login;
- create user;
- reset password;
- change status;
- change permissions;
- register/revoke/remove device;
- global sign-out/security action.

A cached/persistent session may keep the shell usable during a temporary outage, but authority mutation cannot be queued as an offline command.

Future offline cash sales belong to the transaction/offline milestone and must independently define what happens when a previously valid user becomes revoked while offline.

---

## 16. Error Handling and User-facing Copy

Security failures use simple operational language and do not expose SQL, RLS details, JWT internals, or secret identifiers.

Required cases include:

- permission changed: `Akses Anda untuk tindakan ini telah berubah.`
- session/device revoked: clear local session and return to login;
- LEAVE: `Akun sedang berstatus Cuti. Hubungi Owner.`
- DISABLED: `Akun dinonaktifkan. Hubungi Owner.`
- duplicate active shift found later: do not create another shift; direct to existing shift;
- unauthorized foreign resource ID: generic access denied, not a data-existence oracle.

Network failure must be distinguishable from a true authorization denial so users are not incorrectly told they were deactivated merely because connectivity failed.

---

## 17. Audit Requirements

Identity/security changes are auditable events, including at least:

- user created;
- password reset initiated/completed as appropriate without logging passwords;
- display name changed;
- role/preset changed;
- permission override changed;
- status changed;
- device registered/renamed/revoked/removed from active list;
- session revoked;
- global sign-out initiated.

Audit records retain actor, target, action, timestamp, and relevant before/after non-secret metadata.

Passwords, refresh tokens, access tokens, secret keys, and PIN plaintext must never appear in audit logs.

---

## 18. Security Requirements

- No service/secret credential in browser code, source packages, logs, or committed environment files.
- Client uses only appropriate publishable credentials.
- Auth Admin operations run server-side and re-check Owner authority.
- Public self-signup does not create application staff authority.
- RLS/server checks remain fail-closed.
- Mutable permission/status is not trusted solely from stale JWT custom claims.
- Device IDs are random application identifiers, not hardware fingerprinting.
- User and business history is preserved; security/account lifecycle does not hard-delete business facts.
- Security-sensitive helper functions are not executable by unauthorized client roles.

---

## 19. Hosted `private.schema_versions` Verification Item

A current Supabase advisory reports RLS disabled on `private.schema_versions`. Existing read-only verification found:

- anon has no schema usage and no table SELECT/INSERT/UPDATE/DELETE privilege;
- authenticated currently has schema usage but no table SELECT/INSERT/UPDATE/DELETE privilege;
- the schema is intended as a non-exposed private boundary.

CS-03 must include a negative-security verification that the table remains unreachable through the client/Data API path actually used by the application.

This design does **not** authorize automatic `ALTER TABLE ... ENABLE RLS` remediation. Any DDL change requires evidence that the current private-schema/grant boundary is insufficient and requires explicit migration approval.

---

## 20. Testing Strategy

CS-03 is not complete without positive and negative tests.

### 20.1 Identity tests

- normalized username is unique;
- invalid username normalization cases are rejected;
- no self-signup path can obtain application membership/Owner authority;
- Auth user/profile binding is one-to-one according to the final migration design.

### 20.2 Status tests

- ACTIVE user succeeds when permission allows;
- LEAVE user is denied and prior active sessions cannot perform protected commands;
- DISABLED user is denied and prior active sessions cannot perform protected commands;
- reactivation requires fresh login as designed.

### 20.3 Permission tests

- preset permission applies;
- ALLOW/DENY override applies;
- current permission change affects protected operations without re-login;
- hard Owner-only permission cannot be granted to Kasir through an override;
- Kasir cannot read another user's scoped resources.

### 20.4 Device/session tests

- remembered valid session reopens app without credential prompt;
- revoked device/session is denied on protected command;
- one user's multiple trusted devices can coexist;
- shared-device switch does not leave two locally active auth users;
- device removal cannot bypass revocation;
- global sign-out semantics remove access as designed.

### 20.5 Server-boundary tests

- anon is denied;
- authenticated user without business membership is denied;
- non-Owner cannot call user-management/admin functions;
- service/secret key is absent from production frontend bundle;
- direct table writes remain blocked where domain RPC/command is authority;
- `private.schema_versions` remains inaccessible through client-facing API context.

### 20.6 Future integration contract tests

CS-03 should provide fixtures/interfaces that later allow Shift tests to prove:

- user cannot open a second concurrent active shift;
- user cannot operate another user's shift;
- Owner sale requires Owner's active shift;
- device switch does not change shift owner.

These are interface-contract tests in CS-03 only where feasible; full Shift tests belong to the Shift milestone.

---

## 21. Verification and Quality Gates

Before CS-03 implementation can be locked:

1. targeted tests pass;
2. full repository verification passes;
3. `git diff --check` passes;
4. no secret or forbidden path is introduced;
5. migration registry/checksums are consistent if DDL is approved;
6. hosted migration ledger matches the approved forward migration mechanism;
7. Supabase Security Advisor is reviewed after DDL;
8. negative hosted authorization tests pass;
9. PR checks pass;
10. Preview smoke testing passes for the authentication/user/device UI included in CS-03;
11. `main` merge requires explicit user approval;
12. Production deployment remains separately gated and currently disabled by design.

---

## 22. Zero-cost Constraints

CS-03 must remain zero-cost-first.

- Do not depend on Supabase Pro-only session lifetime/single-session settings for core correctness.
- Do not require SMS/OTP provider spend.
- Do not require paid identity provider/SSO.
- Session/device limits needed by the product are enforced by application authority, not by paid platform session controls.
- Usage-impacting polling must be avoided; authorization checks should be bounded to protected operations and sensible refresh points.

---

## 23. Change-Control Notes

Two approved design decisions alter or sharpen business/authority semantics beyond wording-only refinement and therefore must be recorded in the canonical Decision/CR Register before implementation that depends on them is finally locked:

1. **All completed sales, including Owner sales, require the actor's active Actual Shift.**
2. **Actual Shift ownership is immutable; shift settings are snapshotted at open, and handover creates a new shift rather than transferring ownership.**

This Design Spec records the approved intent but does not silently modify protected Blueprint files. The implementation plan must include the appropriate governance update path under existing repository protection rules.

---

## 24. Implementation Boundaries and Sequence

The implementation plan should decompose CS-03 into independently verifiable slices, likely in this dependency order:

1. username/auth/profile binding contract;
2. permission authority and hard boundaries;
3. Owner bootstrap and server-side staff lifecycle actions;
4. persistent session + device/session registry;
5. revocation/status enforcement;
6. frontend route/menu guards and Owner user/device management UI;
7. hosted negative-security verification;
8. documentation/checkpoint and final regression.

The exact tasks, migrations, functions, and file paths are intentionally deferred to the implementation plan after repository inspection and user approval of this written spec.

---

## 25. Definition of Done for the Design Phase

The design phase is complete when:

- this file has no unresolved placeholders;
- the requirements are internally consistent;
- scope is small enough for one CS-03 implementation plan;
- user has reviewed this written spec and approved it;
- the spec exists on an isolated repository branch/PR or equivalent auditable Git commit;
- only then is `superpowers:writing-plans` invoked for the implementation plan.

No CS-03 DDL, production source implementation, PR merge, or Production deployment is authorized by approval of this Design Spec alone.
