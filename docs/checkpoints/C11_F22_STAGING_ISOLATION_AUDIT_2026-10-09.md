# C11-F22 — Audit Isolasi Staging vs. Operasional

Tanggal: 2026-10-09. Repository: `nafialwi/segeran-jiwa-pos-next`.
Branch: `work/c11e-preuat-readiness-termux`.
Baseline: `697ba089d91df3cb5cc9a18fe1371aefe74edabc`.

## Keputusan

**STAGING_ISOLATED = NOT VERIFIED; UAT_DATABASE_WRITES = BLOCKED; CUTOVER_READY = NO.**

Jangan melakukan checkout, seed, migrasi, post batch, pergerakan stok, refund, close shift, atau pengujian yang mengubah database pada URL preview ini. Preview Cloudflare adalah pemisahan aplikasi frontend, **bukan** jaminan pemisahan database.

## Pemeriksaan sumber yang dilakukan (semuanya baca-saja)

| Pemeriksaan                                | Bukti                                                                                                                                                                          | Kesimpulan                                                                                       |
| ------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------ |
| Git awal                                   | HEAD `697ba08`, clean, 0 ahead / 0 behind                                                                                                                                      | checkpoint F21 utuh                                                                              |
| Termux local environment                   | Hanya `.env`; `.env.staging` dan `.env.production` tidak ditemukan                                                                                                             | tidak ada file staging lokal                                                                     |
| Local env reference                        | `VITE_SUPABASE_URL` merujuk `pkynjaqrxhhnnfuaxoqp`; publishable key ada (nilai disembunyikan)                                                                                  | default lokal memakai proyek Segeran Jiwa yang sudah ada                                         |
| Supabase projects (akun terhubung)         | `segeran-jiwa-pos-next` = `pkynjaqrxhhnnfuaxoqp` (ACTIVE_HEALTHY); `kdkmp-manager-workspace` = `xsursmjbpngyywavplbb` (ACTIVE_HEALTHY)                                         | tidak ada proyek ketiga khusus staging POS pada akun ini; **KDKMP bukan opsi staging**           |
| Supabase development branches              | `list_branches(pkynjaqrxhhnnfuaxoqp)` mengembalikan `[]`                                                                                                                       | tidak ada Supabase branch staging untuk proyek POS                                               |
| Cloudflare branch preview, aset publik     | GET **hanya HTML/JS statis** dari `https://work-c11e-preuat-readiness-t.segeran-jiwa-pos-next.pages.dev/`; 49 JS asset dipindai, ref Supabase `pkynjaqrxhhnnfuaxoqp` ditemukan | preview branch masih memakai **ref yang sama dengan `.env` lokal**                               |
| Cloudflare preview historis RC4            | GET aset publik `https://608af457.segeran-jiwa-pos-next.pages.dev/` juga memuat ref `pkynjaqrxhhnnfuaxoqp`                                                                     | historis pun bukan bukti isolasi backend                                                         |
| Cloudflare default production domain       | HTML/JS statis domain `https://segeran-jiwa-pos-next.pages.dev/` tidak memuat ref Supabase yang dapat diidentifikasi                                                           | **tidak cukup bukti** untuk menentukan konfigurasi koneksi backend produksi dari domain tersebut |
| Cloudflare dashboard environment variables | Belum dapat diperiksa; CLI `wrangler` di Termux mengarah ke binary yang tidak ada                                                                                              | pembuktian environment vars Preview/Production secara resmi **tertunda**                         |
| GitHub Actions                             | canonical CI menjalankan `npm run verify`, bukan pemeriksaan isolasi database                                                                                                  | CI hijau ≠ staging siap transaksi                                                                |
| Cutover gate                               | `node scripts/cutover-readiness.mjs`: `CUTOVER_READY=NO`                                                                                                                       | manifest menunjuk kandidat lama, gerbang aman tetap tertutup                                     |

### Batas kesimpulan

Satu referensi Supabase sama pada **local env dan deployed preview**; Supabase yang terhubung tidak memiliki proyek POS staging maupun development branch. Jadi **pemisahan staging belum tersedia/terbukti pada lingkungan yang dapat diperiksa**. Ini bukan bukti bahwa database pernah dimodifikasi, dan tidak membuktikan bahwa domain produksi saat ini memuat bundle identik. Kredensial, isi tabel, auth session, dan data finansial sama sekali tidak dibaca.

## Perlindungan baru F22

Ditambahkan `scripts/staging-isolation-gate.mjs`, pemeriksa konfigurasi lokal **read-only** tanpa dependensi jaringan, Supabase client, ataupun operasi filesystem tulis. Wajib mengisi:

- `--staging-env` (file staging khusus),
- `--production-ref` (project ref operasional yang harus dilindungi),
- `--preview-ref` (project ref dari JavaScript preview yang benar-benar dipublikasikan).

Gerbang menolak file staging hilang, key browser kosong/berjenis server secret, URL tidak standar, staging = operasional, preview = operasional, dan preview tidak sama dengan staging. Contoh pemeriksaan yang **disengaja gagal** pada kondisi F22:

```bash
node scripts/staging-isolation-gate.mjs \
  --staging-env .env \
  --production-ref pkynjaqrxhhnnfuaxoqp \
  --preview-ref pkynjaqrxhhnnfuaxoqp
# status BLOCKED, exit 2, STAGING_AND_OPERATIONAL_PROJECT_ARE_IDENTICAL
```

Tanpa file `.env.staging`, kode juga memblokir dengan `STAGING_ENV_NOT_READABLE`. Bahkan jika memperoleh hasil `CONFIG_DISTINCT_ONLY` dengan proyek baru, properti `uat_allowed` **tetap false** sampai staging live, RLS, autentikasi, data uji, dan otorisasi tindakan diverifikasi terpisah.

## Pekerjaan yang dapat dilakukan tanpa menyentuh database

- Audit statis konfigurasi selesai.
- Gate fail-closed dan tes unit regresi untuk skenario aman/tidak aman.
- Dokumentasi runbook staging yang memastikan isolasi backend, bukan sekadar branch frontend.
- Seluruh skrip/tugas F22 dibatasi pada repository (tidak ada deploy atau pembuatan Supabase project/branch).

## Belum selesai — wajib sebelum F22 UAT bisnis

1. **Keputusan pemilik lingkungan:** setujui project staging POS **terpisah**, atau cabang pengembangan Supabase yang isolasinya terverifikasi. Periksa biaya lebih dulu; jangan mengasumsikan gratis.
2. Siapkan staging menggunakan kredensial dan pengaturan tersendiri; jangan pernah memakai KDKMP atau menyalin data pelanggan asli sembarangan.
3. Deploy Preview dengan `VITE_SUPABASE_URL` dan publishable key untuk staging; cek konfigurasi Cloudflare Dashboard serta **bundle JavaScript yang dipublikasikan**.
4. Jalankan audit read-only ulang dan gate hingga project ref preview = staging ≠ operasional.
5. Verifikasi security/RLS/roles, migration set, akun uji dan seed sintetis di staging; lakukan simulasi transaksi **hanya setelah persetujuan pengguna** dan isolasi terbukti.
6. Tindaklanjuti workbook F21 (44 tes); seluruh skenario belum teruji pada aplikasi nyata.
7. Lakukan UAT, regresi akhir, manifest release yang baru, dan persetujuan deploy tersendiri.

**Estimasi perencanaan menuju final tetap ~76%** dari F21, bukan naik karena skrip audit. Penolakan cutover mengungguli nilai persentase.

## Hasil final audit dan quality gate F22

- Repo guard **PASS**, Prettier **PASS**, ESLint **PASS**, TypeScript **PASS**.
- Vitest **107/107 PASS** dan Python **546/546 PASS** (termasuk **8** tes staging-isolation baru).
- Vite production build **PASS** dan `git diff --check` **PASS**.
- Pemeriksaan dengan `.env` aktual menghasilkan `BLOCKED / STAGING_AND_OPERATIONAL_PROJECT_ARE_IDENTICAL` (exit **2**, sesuai desain).
- Pemeriksaan `.env.staging` yang belum ada menghasilkan `BLOCKED / STAGING_ENV_NOT_READABLE` (exit **2**, sesuai desain).
- Status **isolasi staging tetap BLOCKED**, UAT mutatif tidak dijalankan. Hasil GitHub CI harus diverifikasi setelah commit/push.
