# C11-F2 — Visual Geometry & Readability Safe Point

Date: 2026-09-23

## Purpose

C11-F2 hardens the visual layer so Segeran Jiwa Next feels internally consistent,
readable, and deliberate on daily-use mobile screens without changing business
authority.

This batch directly addresses final-fit concerns raised during Legacy-vs-Next
comparison:

- text that is too small or inconsistent;
- controls that feel like they belong to different visual systems;
- long labels/names escaping their frame;
- cards/sheets with inconsistent corner treatment;
- mobile form controls that can zoom or feel cramped;
- product cards becoming too hard to read at higher grid density.

Baseline:

- branch: work/c11-visual-convergence
- baseline commit: 65c380da55b8d7e6f6c9652b33788e8e7fedf4f1
- database/schema: unchanged
- Production: untouched

## What changed

### 1. Typography contract

Added reusable readability tokens:

- micro text: 0.68rem;
- caption text: 0.72rem;
- small text: 0.78rem;
- body text: 0.875rem;
- body line-height: 1.45.

The goal is to stop ad-hoc tiny labels from proliferating and make future
refinement use one readable scale.

Form controls now explicitly inherit the application font across button, input,
select, and textarea.

### 2. Text containment and wrapping

Common headings, labels, buttons, table cells, card copy, and status messages now
have overflow-safe behavior.

Grid/flex children on important surfaces receive min-width: 0 so long product
names, usernames, device labels, headings, and report values cannot force their
container wider than the available viewport.

Long-text handling is applied to Product, User, Device, table, error, and success
surfaces without truncating business facts silently.

### 3. Geometry contract

Added final-use geometry tokens:

- control radius: 12px;
- card radius: 16px;
- sheet radius: 22px;
- minimum daily touch target: 44px.

Primary/secondary buttons, chips, common cards, operational panels, report
surfaces, user/device cards, and focused work panels now converge on these
families instead of using unrelated one-off geometry.

Dialog behavior remains context-aware:

- mobile bottom sheets keep rounded top corners and flat bottom edges;
- centered desktop dialogs use rounded corners on all sides.

### 4. Daily-use readability corrections

Raised or normalized small text on:

- bottom navigation;
- dashboard captions and quick actions;
- inventory metadata;
- Product & Recipe metadata;
- stock-count headers;
- Shift summaries;
- Control Center helper text;
- Purchase workflow labels;
- searchable picker metadata;
- Finance summary labels;
- User/device labels;
- packaging reconciliation labels.

### 5. Jual product-card readability

Product-card typography is explicitly normalized so visual density does not make
the catalogue unreadable.

Normal density now uses clearer product, variant, and price sizing.

Four-column density remains compact, but uses the readability floor rather than
the earlier micro-sized product text.

Product visual caption, stock badge, cart caption, and density label also share
the new readable micro/caption scale.

### 6. Mobile form ergonomics

At phone widths, input/select/textarea use 1rem font size to avoid browser zoom
behavior and improve numeric/text entry legibility.

Common action buttons maintain a minimum touch target and are allowed to wrap
their label instead of pushing text outside their frame.

Tables retain horizontal containment/overscroll behavior rather than widening the
whole application.

## What this batch intentionally did NOT change

C11-F2 is presentation hardening only. It does not change:

- checkout or sale authority;
- inventory movement authority;
- Shift open/close authority;
- Finance ledger semantics;
- Product/Variant/Recipe business rules;
- report query authority;
- role/permission decisions;
- database schema or migrations;
- production deployment.

Still pending after this safe point:

- Product Media upload/replace/remove/compress;
- Perhatian -> Laporan primary navigation change with permission-safe behavior;
- remaining native browser prompt/confirm replacement;
- deeper per-screen focused-surface cleanup where still useful;
- mobile numeric-keyboard/input-mode sweep;
- final 320/360/390/412 + desktop real-device visual matrix;
- Owner/Kasir end-to-end UAT;
- final C11 fit-and-proper regression/lock.

## Verification

Focused C11-F2 regression:

- 7/7 PASS

Canonical repository verification:

- repo guard: PASS
- Prettier: PASS
- ESLint: PASS
- TypeScript: PASS
- JavaScript: 96/96 PASS
- Python: 388/388 PASS
- production build: PASS
- git diff --check: PASS

The build still reports the existing Vite ineffective-dynamic-import advisory for
src/lib/supabase.ts. C11-F2 does not introduce that advisory.

## Safety conclusion

C11-F2 is a safe presentation checkpoint. It improves consistency, readability,
text containment, touch geometry, and product-card legibility while preserving
all backend/business authorities.

Next intended batch: daily-navigation/report convergence and Product Media, kept
separate because those involve permission/data/storage decisions rather than
purely visual hardening.
