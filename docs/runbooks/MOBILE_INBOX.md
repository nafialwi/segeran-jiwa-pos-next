Normal workflow — Android browser

1. Buka repository Segeran Jiwa POS Next di GitHub melalui browser HP.
2. Pilih branch mobile-inbox.
3. Buka folder inbox.
4. Pilih Add file → Upload files.
5. Pilih tepat satu ZIP package untuk milestone aktif.
6. Commit upload ke mobile-inbox.
7. Buka Actions/PR hanya untuk melihat hasil.
8. Jika Preview sudah tersedia, lakukan QA di HP.
9. Berikan approval milestone hanya setelah hasil sesuai.

# Mobile Inbox Operator Runbook

## Tujuan

Workflow normal setelah `CS-01 LOCKED` adalah one-upload workflow dari browser Android. Pengguna berperan sebagai Owner/approver dan real-device tester; pekerjaan lint, test, build, intake, branch, dan PR harus diotomasi sejauh teknis memungkinkan.

## Aturan branch dan release

- Jangan pernah upload ZIP transit ke `main`.
- `mobile-inbox` adalah branch transport/state, bukan source Production.
- Jangan edit manual branch `work/**` yang dibuat automation selama intake normal.
- Satu commit upload normal hanya boleh mengubah satu ZIP di folder `inbox/`.
- Upload package tidak boleh mempromosikan Production.
- Merge/release/Production tetap memerlukan gate dan approval yang sesuai milestone.

## Setelah upload

1. Tunggu GitHub Actions memproses package.
2. Lihat report/Actions/PR untuk status.
3. Jika intake berhasil, tunggu Preview.
4. Lakukan real-device QA di HP.
5. Berikan approval hanya jika hasil sesuai acceptance criteria.

## Jika gagal

- Jangan langsung membuka Termux.
- Baca failure report terlebih dahulu.
- Pastikan alasan gagal dipahami sebelum retry.
- Gunakan urutan recovery pada `RECOVERY.md`.

## Duplicate dan retry

- Package gagal boleh diperbaiki dan dicoba kembali selama belum ada success receipt.
- `package_id` yang sudah sukses bersifat immutable.
- `retry_safe: true` dengan ZIP yang identik dengan receipt sukses adalah idempotent no-op, bukan re-application.
- `retry_safe: true` dengan content berbeda tetapi `package_id` sama harus ditolak.

## Source of truth

- Blueprint baseline: `v1.0 FINAL LOCK`.
- Snapshot workflow authority: `docs/blueprint/15_WORKFLOW_PROFILE.md`.
- Checkpoint/state aktual proyek harus dibaca dari checkpoint terbaru, bukan dari snapshot BP-LOCKED.
