# Segeran Jiwa POS Next — Complete Chat Handoff — 2026-09-28

## START HERE IF CHAT CONTEXT IS LOST

This file is the primary resume document for the next ChatGPT/Expert session.

Do not restart C11 from the old PC handoff. Do not reset to `work/c11-visual-convergence`, `main`, or any older C11 tag merely to make branches look aligned.

The correct current work line is the Termux line documented below.

## Current repository identity

- Repository: `/data/data/com.termux/files/home/WORKSTATION/projects/segeran-jiwa-pos-next`
- Current branch: `work/c11e-preuat-readiness-termux`
- Current HEAD: `aa5ac8988c912919a2896671e93eac2c17b08146`
- Upstream: `origin/work/c11e-preuat-readiness-termux`
- Upstream HEAD: `aa5ac8988c912919a2896671e93eac2c17b08146`
- Ahead/behind at handoff creation: `0 / 0`
- Working tree at handoff creation: clean
- Current HEAD commit: `docs(c11): add visual professionalization precision roadmap`

Application code last changed before the two documentation commits:

- app-source gate commit: `6e09933b5142624f34a08dd7ebc252c0d217c9bd`
- automated evidence commit: `a71d0513621f0631a0f199663be6d99f157e3d46`
- `aa5ac89` changes roadmap/documentation only; it does not change application runtime behavior.

## Formal project status

Use this exact status until new evidence changes it:

`C11-E AUTOMATED PRE-UAT PASS / VISUAL-INTERACTION ACCEPTANCE PENDING / HUMAN UAT PENDING / FINAL LOCK NOT YET / PRODUCTION LOCKED`

Whole-project earned roadmap progress remains **95.0%**. The final 5% is intentionally unearned.

## Authoritative documents to read first

1. `docs/checkpoints/ROADMAP_PROGRESS.md`
2. `docs/checkpoints/C11_VISUAL_PROFESSIONALIZATION_ROADMAP_2026-09-28.md`
3. `docs/checkpoints/C11E_PRE_UAT_AUTOMATED_GATE_2026-09-25.md`
4. `docs/uat/UAT_C11E_PRE_UAT_2026-09-25.md`
5. `docs/checkpoints/P5D2_AUTHENTICATED_SECURITY_DEFINER_REVIEW_CHECKPOINT.md`
6. `docs/checkpoints/P5C_BACKUP_RESTORE_CHECKPOINT_REPORT.md`
7. `docs/checkpoints/RELEASE_MANIFEST.json`
8. this handoff file

If evidence conflicts, prefer the newest exact Git/source evidence and preserve fail-closed behavior.

## Completed C11 implementation line

The current source line includes, in order:

- `724bcf0` — preserve session on transient authority failure;
- `b89177e` — persist Sales draft and checkout operation identity;
- `3ea6e6f` — compact Sales flow and clarify cart summary;
- `cd1b1d2` — guard account exit while active work exists;
- `a1990de` — explicit Product and Variant editing;
- `260d547` — unread operational attention;
- `9580b56` — handover/reconciliation/approval UX;
- `f0a6978` — operational loading/empty-state convergence;
- `15c2078` — visual-density normalization;
- `7f0d86c` — shared operational status labels;
- `138a933` — remaining secondary-screen convergence;
- `8e81a41` — C11-E route authority and fresh-UAT preparation;
- `6e09933` — pre-UAT quality and fail-closed cutover hardening;
- `a71d051` — automated pre-UAT evidence;
- `aa5ac89` — visual professionalization/precision roadmap.

Do not repeat C11-A/B/C/D implementation from scratch unless a regression test or Human UAT proves a defect.

## Automated evidence already achieved

For the pre-UAT application candidate:

- JavaScript: **107/107 PASS**
- full Python discovery: **476 tests PASS**
- repository guard: PASS
- Prettier: PASS
- ESLint: PASS
- TypeScript: PASS
- production build: PASS
- git diff-check: PASS
- GitHub Actions canonical verify: PASS
- automatic Production deployment: disabled
- cutover check: expected **CUTOVER_READY=NO** while the release manifest still points to an older candidate

Do not turn CUTOVER_READY into YES by prematurely changing the manifest.

The release manifest must advance only after fresh Human UAT and final regression on the exact approved candidate.

## Earlier user complaints that remain part of acceptance

These complaints are not erased by a commit named visual-convergence.

### Sales / Jual

- Header Jual was too large and wasted mobile vertical space.
  - Source has already removed the redundant Beranda breadcrumb and compacted the header to roughly 38–42 px.
  - Status: IMPLEMENTED / HUMAN-CLOSE PENDING.
- Quantity/in-cart number was observed rendering below the product image instead of as a stable overlay.
  - Source intends an overlay, so the observed behavior is treated as a real visual regression.
  - Status: **OPEN V-P0**.
- Product grid and cards felt too tall/crowded and not precise.
- First product row should appear earlier with less chrome before it.
- 2/3/4-column switching must remain usable, but density must not sacrifice readability.
- Click/tap feedback must be immediate and obvious.
- Product images must be present and product-media upload/replace/remove must be understandable.
- Quantity, Cash, QRIS, Transfer, and Kasbon state must not visually leak from a previous transaction.

### General visual complaints

- inconsistent font sizes;
- inconsistent radius/box geometry;
- text escaping or wrapping poorly;
- large cards/lists forcing excessive scrolling;
- selected detail appearing too far below the current viewport;
- UI that technically works but still feels visually 'wagu', crowded, or developer-oriented;
- mobile-first behavior must remain good without breaking desktop.

## Visual roadmap now officially locked

The visual roadmap is a sub-gate of the existing final 5%; it does not change project weight.

### V-P0 — close visible defects first

- reproduce and fix Sales quantity-badge positioning;
- anchor the badge to a dedicated image/card positioning context;
- verify Sales on 320, 360, 390–412, tablet, and desktop widths;
- confirm no clipped text, horizontal overflow, floating controls, or keyboard-covered actions.

### V-P1 — make Sales/POS professional

- keep the compact Sales header;
- reduce vertical controls before the first product row;
- simplify product cards so image, name, and price dominate;
- show secondary status only when informative;
- remove permanent `Pilih produk` and repeated category text when redundant;
- use 2 columns as the safe mobile default unless real-device evidence proves 3 columns equally readable;
- keep 3/4 columns as explicit density choices;
- define minimum readable font sizes for names, prices, chips, secondary labels, and bottom navigation.

### V-P1 — clean business language

Remove user-facing implementation vocabulary such as:

- `READ MODEL`;
- ledger architecture explanations;
- `Product/Variant` when `Produk & Varian` is clearer;
- `ingredient sale-stage`;
- `finished good`;
- unnecessary BOM/compatibility language.

Developer concepts belong in documentation, not routine Owner/Kasir UI.

### V-P1 — Owner/admin hierarchy

- reduce same-weight action clutter on User and Device cards;
- keep daily actions visible;
- move destructive/rare actions such as reset password, leave/disable, revoke/remove device into a secondary controlled flow;
- keep confirmations, permissions, and audit trails intact;
- group long permission lists into scannable sections without changing authority semantics.

### V-P1 — Reports/history usability

- quick periods are the primary report path;
- custom date range appears only when needed;
- summary remains compact with drill-down on demand;
- 100 transactions must remain practical to review;
- selected detail appears immediately and predictably;
- mobile full-detail views remain readable.

### V-P2 — shared visual-system convergence

- standardize header geometry across Sales, Operations, Reports, Finance, History, and secondary screens;
- normalize spacing, radius, icon sizes, typography, section gaps, and status chips;
- reduce unnecessary gradient + radial-gradient + border + shadow combinations;
- reserve strong elevation for actual floating surfaces such as cart bars, dialogs, and sheets;
- keep clear active/selected/success/warning/danger/disabled/loading/offline states.

### V-P2 — CSS authority consolidation

`src/app.css` contains multiple layered C11 overrides for high-impact selectors.

Do not perform a broad rewrite before visible defects are closed.

After V-P0/V-P1, consolidate the final authority for Sales header/card/badge, shared headers, cards/buttons, reports, and responsive breakpoints while preserving all tests.

A CSS selector being present is not proof that a visual complaint is closed.

## Mandatory interaction regressions

Re-test the previously reported stale-state behavior:

- quantity +/- visual feedback;
- Cash / QRIS / Transfer / Kasbon selection;
- QRIS/Transfer confirmation state after completing a sale;
- shift open/close input values;
- account switch/logout with active draft/shift;
- software keyboard and checkout bottom sheet;
- click/tap feedback and focus visibility.

PASS means a new sale/shift begins with the correct clean state and no visual residue from the prior flow.

## Fresh Human UAT still required

Do not inherit a PASS verdict from RC1/RC2/RC3/RC4 or another older immutable candidate.

### Continuity UAT

- login as Kasir;
- reload;
- close/reopen browser/PWA;
- transient network failure during authority refresh;
- restore network and retry;
- confirm valid sessions recover without false logout.

### Draft/checkout continuity UAT

- create a cart with multiple products, quantity, note, payment choice, and discount when permitted;
- close/reopen before payment;
- confirm draft restores only to the same profile + shift;
- confirm QRIS/Transfer confirmation does not restore as already verified.

### Ambiguous checkout UAT — critical P0

- interrupt connectivity where server commit may already have succeeded;
- reopen and use the persisted operation identity;
- inspect history and stock facts;
- PASS requires exactly one sale and exactly one stock effect;
- duplicate or lost committed sale = P0.

### Kasir daily journey

- Beranda → Perhatian → Shift → Jual → search/category → 2/3/4 columns → quantity/note → Cash/QRIS/Transfer/Kasbon → discount → success → Riwayat → account exit guard.

### Owner/Admin journey

- Produk & Resep / Edit Produk / Edit Varian;
- product-media upload/replace/remove;
- inventory and stock control;
- purchase, production, finance, reports/export;
- operational messages and attention;
- handover, reconciliation, expense approval;
- users/permissions/devices;
- control center, backup/restore, health, offline/sync, diagnostics.

## Security and production-hardening context

P5D2 checkpoint on 2026-09-21 reviewed the then-current authenticated SECURITY DEFINER surface:

- 60/60 functions classified;
- 60/60 empty search_path;
- 0/60 executable by anon;
- Connector V2 four anonymous RPCs separately token-gated;
- leaked-password protection documented as unavailable on the Free plan and accepted as an explicit limitation.

A later advisor scan during the 2026-09-28 audit reported a larger current authenticated SECURITY DEFINER surface than the old 60-function checkpoint.

Therefore, before Production:

- rerun a full current RPC privilege/guard sweep against the exact final candidate;
- do not assume the 2026-09-21 count covers functions added afterward;
- verify new/changed functions preserve explicit Owner/permission/business/session/shift authority checks;
- keep Connector bridge token checks fail-closed.

Performance-advisor findings from the later audit were not Human-UAT blockers:

- foreign keys without covering indexes;
- RLS init-plan inefficiencies on bridge tables;
- many indexes not yet observed in use.

Do not mass-delete indexes based only on low/zero observed use before representative production traffic.

## Backup / restore state

P5C historical checkpoint is LOCKED_REMOTE:

- real pg_dump archive created;
- retained copy SHA matched;
- isolated restore completed with return code 0;
- representative restored row counts were verified;
- temporary broad read path was disabled afterward.

Before final Production cutover, rerun backup-health/restore readiness on the exact final release candidate if the release runbook requires fresh evidence.

## Release and preview safety

- Production automatic deployment must remain disabled.
- A preview smoke was previously available, but exact preview-to-final-candidate identity must be reverified before final Human UAT/release evidence.
- `docs/checkpoints/RELEASE_MANIFEST.json` intentionally identifies an older approved candidate while fresh C11 UAT is incomplete.
- `CUTOVER_READY=NO` from that source mismatch is expected and correct.
- Never change the manifest merely to make the cutover check green.

## Branch/history cautions

Historical PC-only documentation commit:

- `5a1f44a docs: add C11 finalization continuity handoff`

That commit was absent from the Termux repository when C11-E was audited.

Do not reset the newer Termux source to recover that old documentation commit. If needed, reconcile documentation content only.

Other important references:

- stale parent branch: `work/c11-visual-convergence @ 742aa86`
- current work line is many commits ahead of that branch
- `main` is not the current C11 source of truth

Canonical reconciliation belongs after fresh Human UAT and final regression, not before.

## Exact next-work order for the new chat

1. Verify live Git identity, clean tree, upstream sync, and current HEAD.
2. Read this handoff plus the visual roadmap and C11-E UAT documents.
3. Do not start with broad feature development.
4. Start with **V-P0 Sales quantity-badge reproduction/fix**.
5. Inspect current Sales DOM/CSS authority and remove the root cause, not just add another blind override.
6. Run targeted Sales/visual tests plus typecheck/build for each bounded change.

7. Verify the affected viewport on a real device or an evidence-quality preview.
8. Continue V-P1 Sales hierarchy/card cleanup.
9. Continue business-language, Owner/admin hierarchy, Reports/History cleanup.
10. Perform V-P2 shared visual convergence and bounded CSS consolidation.
11. Run the complete real-device visual matrix.
12. Perform the fresh Human UAT journeys, including ambiguous checkout.
13. Resolve P0/P1 findings only through bounded tested changes.
14. Re-run current production security/authority sweep.
15. Run full final regression on the exact post-UAT candidate.
16. Reconcile canonical branch and any documentation-only PC handoff if still relevant.
17. Advance release manifest only after all gates are clear.
18. Create immutable final tag/checkpoint.
19. Production release remains a separate explicit decision.

## Visual closure rule

Use these states only:

- OPEN
- PARTIAL
- CLOSED — VERIFIED
- REGRESSION

Never close a visual complaint merely because a CSS rule, source assertion, commit name, or automated test exists.

The intended viewport/device must be verified.

## Final C11 exit criteria

C11 can move to FINAL LOCK only when all are true:

- V-P0 = 0;
- V-P1 = 0;
- remaining V-P2 items are explicitly accepted/documented;
- fresh Human UAT is complete on the exact final candidate;
- P0 = 0;
- P1 = 0;
- accepted P2/P3 are documented;
- Product Media is human-retested;
- ambiguous-checkout/idempotent retry is evidenced;
- no stale payment/shift UI state remains;
- full JavaScript/Python/format/lint/typecheck/build/repo/diff gates pass;
- current RPC/security authority sweep is clear or explicitly accepted;
- backup/release evidence is fresh enough for the release runbook;
- canonical reconciliation is complete;
- release manifest SHA equals the exact approved final HEAD;
- immutable final tag/checkpoint exists;
- Production release is separately and explicitly approved.

Required acceptance vocabulary:

- `F-PASS` = functional behavior accepted;
- `A-PASS` = architecture/authority flow accepted;
- `V-PASS` = visual/interaction behavior accepted.

Final Lock requires all applicable gates, not automated tests alone.

## New-chat bootstrap

Recommended first user message in the new chat:

`Expert, lanjutkan Segeran Jiwa Next dari docs/checkpoints/C11_COMPLETE_CHAT_HANDOFF_2026-09-28.md. Cek repo live via Termux/Remote Commander, jangan reset branch, lalu mulai dari pekerjaan OPEN paling prioritas sesuai handoff.`

The next assistant should:

1. read this handoff first;
2. verify live repo state;
3. report any drift from this checkpoint;
4. continue from V-P0 rather than re-planning the whole project.

## Handoff checkpoint

At the time this handoff was authored:

- current branch before this handoff commit: `work/c11e-preuat-readiness-termux`;
- current remote-synced HEAD before this handoff commit: `aa5ac8988c912919a2896671e93eac2c17b08146`;
- working tree was clean before the handoff document was created;
- the handoff itself must be committed and pushed, and the resulting commit becomes the new resume HEAD.
