# C11-F23 — DEV Backup, Migration, and Security Pre-UAT Audit

**Tanggal:** 2026-10-10 WIB

**Repository:** `nafialwi/segeran-jiwa-pos-next`

**Parent:** F22B `2e1756d85a41ca8102e55d15be42c45b551b9825`

## Keputusan

**Development/UAT boleh memakai proyek Supabase `pkynjaqrxhhnnfuaxoqp`; tetapi UAT yang mengubah uang, stok, shift atau master belum boleh dimulai sebelum snapshot terkini dengan pemulihan terverifikasi tersedia.**

Keputusan ini konsisten dengan konfirmasi pengguna bahwa POS Next masih pengembangan dan tidak dipakai operasional. Memakai satu backend development tidak menjadikannya staging yang terisolasi dari produksi yang kelak dibuat. Jangan menyamakan status `CONFIG_DISTINCT_ONLY` dari F22 dengan izin memakai backend yang sama untuk produksi.

Tidak ada SQL tulis, perubahan RLS/grant/Auth, backup palsu, migration push, proses restore, perubahan shift, deployment, atau transaksi dalam checkpoint ini.

## Bukti database yang diperiksa secara read-only

Supabase project ACTIVE_HEALTHY, PostgreSQL 17.

| Pemeriksaan                                             | Data aktual                      |
| ------------------------------------------------------- | -------------------------------- |
| Auth users dan profil                                   | 2 Auth users, 2 profil aktif     |
| Peran                                                   | 1 Owner + 1 Kasir aktif          |
| Penjualan                                               | 7 COMPLETED                      |
| Shift                                                   | 2 OPEN, 3 CLOSED                 |
| Master produk                                           | 30 sale products; 68 stock items |
| Audit / operation receipts                              | 29 / 33                          |
| Purchase orders / production batches                    | 0 / 0                            |
| `pg_policies` public                                    | 60                               |
| `pg_proc` public SECURITY DEFINER                       | 84                               |
| Yang diberi EXECUTE anonim dari fungsi SECURITY DEFINER | 4                                |

**Jangan menghapus baseline data ataupun menutup dua shift yang sedang OPEN tanpa analisis bisnis.**

## Backup nyata — belum lengkap

- Dokumen `P5C_BACKUP_RESTORE_CHECKPOINT_REPORT.md` merekam logical dump + restore terisolasi **pada 21 September 2026** di mesin WSL. Ini historis dan tidak menjamin kondisi database Oktober.
- Pemeriksaan file di Termux menemukan backup source code (.tar.gz) dan file proyek lama, **bukan bundle backup database POS terbaru** yang memuat checksum, salinan terpisah, serta bukti restore.
- `pg_dump` dan `pg_restore` tersedia di Termux, versi **18.2**; tidak ada Docker. Operator tetap membutuhkan koneksi database sah dan target restore terisolasi.
- Gate baru `scripts/dev-uat-backup-gate.mjs` menambahkan pemeriksaan proyek, tanggal minimal, urutan backup/restore, checksum dan salinan ke gate kesehatan backup P5C. **Tidak membaca secret, tidak menghubungi jaringan, dan tidak memodifikasi data.**
- Hasil terhadap folder backup yang tersedia: `BLOCKED / BACKUP_HEALTH_UNVERIFIED`, kode exit 2 sesuai desain. Bahkan jika bukti lengkap, gate tetap mengembalikan `uat_mutations_allowed:false`; pemeriksaan operator tetap wajib.
- Panduan operasional dan format bukti: `docs/runbooks/DEV_UAT_CURRENT_BACKUP_F23.md`.

## Peringatan keamanan — jangan langsung mengubah fungsi

Security Advisor Supabase pada pemeriksaan ini menampilkan:

- 10 `INFO: rls_enabled_no_policy`. Sebagian mungkin sengaja ditutup untuk akses melalui RPC; periksa kontrak akses tiap tabel.
- 4 `WARN: anon_security_definer_function_executable`: `xp_agent_heartbeat_v2`, `xp_claim_job_v2`, `xp_finish_job_v2`, `xp_renew_job_v2`.
- 71 `WARN: authenticated_security_definer_function_executable` (perlu audit izin di dalam fungsi, bukan otomatis rentan).
- 1 `WARN: auth_leaked_password_protection` pada pengaturan Auth.

Inspeksi `pg_get_functiondef` tanpa memanggil RPC menunjukkan keempat XP RPC **memanggil** `xp_bridge_private.authorize_agent(p_agent_id)` sebelum operasi. Pemeriksaan itu mencari header `x-agent-token`, meng-hash-nya dengan SHA-256, membandingkan dengan `token_sha256` untuk agen yang enabled, dan menolak token tidak valid. **Ini kontrol autentikasi aplikasi**, tetapi belum merupakan hasil negative penetration test. Tidak dilakukan `REVOKE`, agar agen Termux aktif tidak diputus tanpa verifikasi.

Deployed Edge Functions `identity-admin` dan `device-admin` menunjukkan `verify_jwt=false` di pengaturan platform, tetapi source aplikasi memanggil `requireOwnerContext` sebelum operasi admin. Implementasi menggunakan bearer token dan `auth.getUser(token)`, memeriksa `session_id` serta `get_my_authority` dan izin Owner. **Harus dites dengan token invalid/Kasir**, jangan serta-merta mengubah `verify_jwt` tanpa menguji kontrak aplikasi.

Lihat informasi resmi lint Supabase:

- [RLS enabled no policy](https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy)
- [Anonymous SECURITY DEFINER](https://supabase.com/docs/guides/database/database-linter?lint=0028_anon_security_definer_function_executable)
- [Authenticated SECURITY DEFINER](https://supabase.com/docs/guides/database/database-linter?lint=0029_authenticated_security_definer_function_executable)
- [Password protection](https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection)

## Migrasi lokal vs riwayat live

Ada **66 file migrasi .sql** di repository dan **53 catatan migrasi live**. Banyak nama/versi berbeda; ini tidak otomatis berarti schema kurang atau migrasi gagal (sebagian pernah dicatat ulang dengan nomor berbeda). **Jangan menjalankan `supabase db push` atau `db reset` secara otomatis.** Perbandingan skema, checksum migration registry dan RPC diperlukan sebelum replay apa pun.

## Yang selesai, yang tertunda, dan berikutnya

**Selesai F23:**

- Inspeksi nonmutatif kondisi data development, backup, tool pg_dump, keamanan RPC dan Edge Functions, serta riwayat migrasi.
- Penolakan fail-closed untuk bukti backup yang hilang/terlalu lama dan tes regresinya.
- Panduan pembuatan dump dan restore terisolasi tanpa membocorkan password di Git.

**Tertunda:**

1. Membuat **logical backup PostgreSQL terbaru** oleh operator yang memiliki akses koneksi sah.
2. Membuat retained copy dan memverifikasi **restore pada target PostgreSQL lain**, bukan database development aktif.
3. Mencocokkan migration registry dan server function definitions.
4. UAT Owner/Kasir login nyata, negative role security, 44 skenario F21, kemudian transaksi yang jelas berlabel data uji.
5. Sebelum go-live, proyek production baru/terisolasi, manifest release final dan persetujuan deployment.

**Checkpoint policy:** Estimated progress toward final remains **~76% (planning only)**. `DEV_UAT_MUTATION_READY=NO` dan `CUTOVER_READY=NO`. Sukses quality gate otomatis bukan pengganti backup atau UAT manusia.

## Quality gate

Delapan tes baru untuk preflight backup. Pemeriksaan Termux akhir: repo guard PASS, Prettier PASS, ESLint PASS, TypeScript PASS, Vitest **107/107 PASS**, Python **554/554 PASS**, Vite production build PASS, git diff check PASS. CI GitHub harus diperiksa setelah push; ini tidak membuktikan backup/restore atau human UAT.
