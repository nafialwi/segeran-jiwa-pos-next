# C11 — Visual Refinement Convergence Context Lock

Date: 2026-09-23

## Baseline

- RC4 remains immutable at `uat-rc-20260922-4`.
- C11 branch: `work/c11-visual-convergence`.
- C11 starts from the post-UAT documentation HEAD after RC4.
- Production automatic deployment remains disabled.

## Visual source of truth

The four approved Segeran Jiwa POS Next refinement boards are the visual target:

1. Application Shell & Dashboards
2. Sales, Checkout & History
3. Inventory, Recipe, Purchase, Production & Shift
4. Settings, Finance, Users, Attention, Backup & Health

RC4 remains the behavioral and security source of truth.

## Non-negotiable boundary

C11 is a presentation convergence phase. It must not weaken or replace:

- transaction authority;
- inventory authority;
- finance authority;
- shift integrity;
- permission/role enforcement;
- offline fail-closed boundaries;
- backup evidence truthfulness;
- security-definer hardening;
- database/source-of-truth semantics.

Any functional change discovered as necessary must be treated as a separately reviewed blocker, not hidden inside visual work.

## C11-A — Brand & Icon System

Canonical UI icon authority is the Legacy locked production SVG family:

`segeran-jiwa-pos-legacy/src/assets/icons/locked`

Evidence:

- locked manifest authority: `SEGERAN_JIWA_ICON_FAMILY_SYSTEM_HANDOFF_LOCKED_B01_B05 / Batch 05 cumulative production set`;
- production SVG count: 61;
- checksum manifest retained with the copied family.

The old POS Next 24 px PNG subset is no longer the canonical icon source.

Brand-logo note: the standalone Segeran Jiwa logo/wordmark asset is not present in the Legacy icon family and remains a separate brand asset task.

## Execution order after C11-A

- C11-B: Shell, dashboard, navigation, menu
- C11-C: POS, cart, checkout, success, history
- C11-D: Inventory, product/recipe, purchase, production, shift
- C11-E: Settings, finance, users/devices, attention, backup/health/offline
- C11-F: 320/360/390/412 px mobile QA + desktop QA + full regression
- RC5 only after C11-F passes

Production remains blocked until RC5 acceptance.
