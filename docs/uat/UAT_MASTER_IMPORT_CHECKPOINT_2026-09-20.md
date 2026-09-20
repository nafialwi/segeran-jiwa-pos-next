# UAT Master Import Checkpoint - 2026-09-20

Status: MASTER_DATA_PREREQUISITE_CLEAR

## Source

- Legacy backup: `backup_segeranjiwa_v58_2026-09-20T11-02-32-867Z.json`
- Source SHA-256: `73668c64c0065e952c769802315c63fa4fd6ae688fdf53f567ca73a620cf75e7`
- Legacy authority node: `root.global`
- Import target location: `GERAI`
- Import method: `public.import_legacy_master`
- Import was executed as the active Owner authority and committed only after verification.

## Pre-import validation

- Menu rows: 68
- Active products: 30
- Archived products: 38
- Track-stock products: 28
- Active track-stock products: 15
- Customer rows: 10
- Inventory keys: 29
- Duplicate product IDs: 0
- Invalid product rows: 0
- Negative stock rows: 0
- Non-numeric stock rows: 0
- QRIS source: present

## Hosted post-import verification

- Stock items: 68
- Active sale catalog rows: 30
- Archived/inactive rows: 38
- Track-stock rows: 28
- Inventory quantity total: 421
- Customers: 10
- Legacy import records: 1
- Missing `base_unit_id`: 0
- QRIS image length: 163375
- QRIS is a renderable data-image payload.
- Active track-stock items with zero stock: 4

## Safety and privacy

- The full 30 MB Legacy transaction/history backup was not uploaded to hosted.
- Only the minimum master subset required by the importer was relayed.
- Temporary relay chunks were deleted after commit.
- Temporary local minimal-payload files were deleted after commit.
- The original operator backup remains in the device Downloads folder.
- Import was transaction-guarded and verified before commit.

## Automated recovery evidence

- Sales hosted regression: PASS.
- Sale retry/idempotency: PASS; retry does not consume stock twice.
- Purchase R3 hosted regression: PASS.
- Purchase replay: PASS; no duplicate PO, GRN, or stock movement.
- Latest source verification before import: 73/73 JS and 154/154 Python PASS; format, lint, typecheck, build and diff-check PASS.

## UAT disposition

The master-data prerequisite that blocked Wave 1B is now CLEAR.

UAT-06 and UAT-08 remain pending a real-device browser rerun. They must not be marked PASS solely from automated or database evidence.
