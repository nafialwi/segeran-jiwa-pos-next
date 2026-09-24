# C11-E — Pre-UAT Readiness / Current Candidate

Date prepared: 2026-09-25

Status: **PRE-UAT AUTOMATED READINESS — HUMAN UAT STILL REQUIRED**

Current development line:

- branch: work/c11e-preuat-readiness-termux
- parent visual safepoint: 138a933783b46302393ebe41ce9a50da33a2aa25
- production automatic deployment: **must remain disabled**
- this document does **not** inherit Human UAT PASS from an older candidate.

## Why a fresh UAT is required

The older F8/RC4 evidence was valid for its immutable candidate, but the current
candidate now also includes:

- transient auth/session continuity;
- persisted cart + checkout operation identity;
- account-exit guard;
- explicit product/variant edit paths;
- operational-message attention integration;
- handover/reconciliation/approval convergence;
- shared operational loading/empty/error states;
- operational visual density normalization;
- shared status labels/tones;
- secondary-screen state and long-text convergence.

Those changes materially affect daily interaction, so final C11 sign-off must be
performed against the current candidate rather than reusing an older UAT verdict.

## Automated pre-UAT gates

Before Human UAT begins, require:

- git diff --check: PASS;
- repository clean at candidate commit;
- TypeScript: PASS;
- JavaScript suite: PASS;
- targeted C11 A/B/C/D/E Python regressions: PASS;
- production build: PASS;
- route/permission projection parity: PASS;
- production automatic deployment remains disabled.

Full Python discovery remains a required final workstation gate. Termux has
previously shown process-runner hangs on the monolithic discovery command, so
targeted tests on Termux are evidence for changed areas, not a substitute for the
final workstation run.

## Human UAT — mandatory continuity journey

### Session / restart

1. Login as Kasir.
2. Reload the page.
3. Close and reopen the browser/PWA.
4. Confirm a valid stored session returns without a login flash.
5. Temporarily disrupt connectivity during authority refresh.
6. Confirm the app reports that the session remains stored rather than silently
   logging out.
7. Restore connectivity and retry verification.

PASS:
- no false logout;
- no unauthorized bypass;
- terminal account/device/session revocation still signs out.

### Cart / draft recovery

1. Open an active shift.
2. Add multiple products and quantities.
3. Add a line note.
4. Set payment method and optional transaction note/discount when permitted.
5. Reload or close/reopen before payment.
6. Confirm draft restores only for the same profile + shift.
7. Confirm removed/unavailable catalog items are reconciled safely.
8. Confirm QRIS/Transfer manual-verification checkboxes do not restore as
   already verified.

PASS:
- no cross-user/cross-shift draft leakage;
- no stale manual payment confirmation.

### Ambiguous checkout / idempotency — critical

Use an operationally acceptable transaction or controlled test environment.

1. Prepare a valid sale.
2. Submit payment.
3. Interrupt connectivity/app response at the point where server commit may
   already have happened.
4. Reopen the app.
5. Confirm Periksa transaksi sebelumnya is presented.
6. Re-verify QRIS/Transfer manually if applicable.
7. Resume using the same persisted operation identity.
8. Check Riwayat and stock facts.

PASS:
- exactly one sale fact;
- exactly one stock effect;
- no duplicate invoice caused by retry;
- no silent loss of the ambiguous operation.

Any duplicate/lost committed sale is **P0**.

## Human UAT — Kasir daily journey

- Beranda;
- Perhatian + unread operational message;
- Shift Saya;
- Jual search/category;
- 2/3/4 product columns;
- add/remove/change quantity;
- line note;
- Tunai;
- QRIS manual verification;
- Transfer manual verification;
- Kasbon/customer selection;
- discount authority;
- success sheet;
- Riwayat;
- logout / Ganti Pengguna while active shift/draft exists.

PASS:
- no stale payment state carries to the next sale;
- account exit guard is understandable;
- no P0/P1 daily-use finding.

## Human UAT — Owner/Admin journey

- Produk & Resep: Edit Produk and direct Edit Varian;
- product media upload/replace/remove retest;
- Persediaan + Detail + Kontrol Stok;
- Pembelian;
- Produksi;
- Keuangan;
- Laporan + export;
- Pesan Operasional create/cancel/read progress;
- Perhatian reflects unread instruction;
- Serah Terima;
- Rekonsiliasi;
- Approval Pengeluaran;
- Pengguna & Izin;
- device management;
- Pusat Kontrol;
- Backup/Restore;
- Health / Offline & Sync / Diagnostics.

PASS:
- menu and direct route access match authority;
- Owner-only routes cannot be reached by Kasir;
- labels/statuses are human-readable;
- loading/empty/error states do not misrepresent data.

## Responsive / interaction matrix

Minimum:

- 320 CSS px smoke;
- 360–412 CSS px Android Kasir;
- 360–412 CSS px Android Owner;
- tablet/large-phone when available;
- desktop Owner.

For each:

- no whole-page horizontal overflow;
- bottom navigation remains reachable;
- long names/messages/references wrap safely;
- keyboard does not permanently cover the active action;
- dialog/sheet close behavior is predictable;
- touch targets remain usable;
- loading → content transition does not show stale prior-record facts.

## Final C11-E exit gate

C11-E can proceed to FINAL LOCK only when:

- fresh Human UAT is completed on the current candidate;
- P0 = 0;
- P1 = 0;
- accepted P2/P3 findings are documented;
- Product Media backend fix is human-retested;
- ambiguous-checkout/idempotency journey is evidenced;
- full workstation Python discovery passes;
- JS/typecheck/lint/format/build/repo/diff gates pass;
- canonical branch reconciliation is complete;
- the PC-only handoff commit is reconciled;
- final candidate commit/tag is immutable;
- production release remains a separate explicit decision.

Until all items above are met: **C11 FINAL LOCK = NOT YET**.
