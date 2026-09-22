# Official UAT RC3 - 2026-09-22

Candidate tag: uat-rc-20260922-3
Candidate commit: 3855e82
Preview: https://f70613ca.segeran-jiwa-pos-next.pages.dev

## Why RC3 exists

RC2 authenticated smoke exposed a real UAT blocker on **Shift Saya**:

`permission denied for table sales`

Root cause: the frontend packaging-usage helper directly queried the protected `public.sales` fact table. This violated the intended authority boundary even though the rest of Shift Saya loaded.

RC3 replaces that direct client read with authenticated RPC `public.shift_packaging_usage(uuid)`, scoped to the active business and either Owner or the cashier owning the shift. The RPC reads immutable sale component snapshots server-side and grants no direct table access.

## Repair evidence

- managed migration `c10_shift_packaging_read_authority`: APPLIED
- `anon` execute on the new RPC: DENIED
- `authenticated` execute on the new RPC: ALLOWED
- SECURITY DEFINER: YES
- pinned empty search_path: YES
- focused C10/C5B/CS02 tests: PASS
- canonical verify after repair: 96/96 JavaScript + 293/293 Python PASS
- format/lint/typecheck/build/diff-check: PASS
- GitHub verify for RC3: PASS
- Cloudflare Pages deploy for RC3: PASS
- Chrome 153 390x844 unauthenticated smoke: PASS
- Production automatic deployment remains DISABLED

## Human UAT status inherited from RC2

Observed before the RC2 blocker:

- Owner login: PASS
- session survived refresh: PASS
- Beranda: PASS
- Jual catalog: PASS
- Riwayat route/filter UI: PASS
- Perhatian route: PASS
- Menu route and Owner module visibility: PASS
- Shift Saya route reached, but RC2 was BLOCKED by the protected-table permission error above

RC2 is therefore superseded for Human UAT.

## RC3 required recheck

1. Sign in to the exact RC3 Preview with the existing authorized Owner account.
2. Open **Shift Saya**.
3. Confirm the prior `permission denied for table sales` banner is gone.
4. Confirm Shift Aktif and the running reconciliation KPIs finish loading.
5. Do not close the real shift and do not create a transaction solely for UAT.

If the Shift recheck passes, continue the remaining batched Human UAT:

- Batch A remainder: responsive/mobile-width and remaining route reachability
- Batch B: sales/payment presentation and guards
- Batch C: inventory/purchase/production
- Batch D: shift/finance/reconciliation
- Batch E: history/reports/offline/health/backup

## Exit rule

Human UAT may be marked PASS only when all required batches are accepted and no P0/P1 issue remains. Any P0/P1 issue requires another source patch, full regression, a new immutable release candidate, and rerun of impacted UAT.

Current status: AWAITING_RC3_HUMAN_RECHECK.
