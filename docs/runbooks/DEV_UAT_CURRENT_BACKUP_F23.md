# C11-F23 — Runbook Backup Development Sebelum UAT Mutatif

Tanggal: 2026-10-10 (WIB). Repo: `nafialwi/segeran-jiwa-pos-next`.

## Kenapa diperlukan

Supabase `pkynjaqrxhhnnfuaxoqp` sekarang khusus **development dan UAT sementara**, sesuai konfirmasi pengguna. Tetapi ia **tidak kosong**: setidaknya 7 transaksi selesai, 5 shift (2 terbuka), 68 item stok, dua pengguna aktif, dan jejak audit. Jangan melakukan `db reset`, menghapus data, mengimpor semua migrasi, atau menutup dua shift tersebut sebagai persiapan otomatis.

Backup logis serta verifikasi restore pernah dilaksanakan pada 21 September 2026 (catatan P5C), tetapi backup tersebut **bukan bukti pemulihan snapshot terkini**. Termux tidak menunjukkan backup database terkini beserta salinan terpisah dan bukti restore. Backup source code bertipe `.tar.gz` **bukan** backup PostgreSQL.

## Yang sudah tersedia tanpa biaya baru

- Termux/Android (aarch64) memiliki `pg_dump` dan `pg_restore` versi **18.2**; server Supabase memakai PostgreSQL 17.
- Debian proot aktif; Docker **tidak diperlukan hanya untuk membuat logical dump**.
- Perangkat mempunyai ruang bebas sekitar 22 GB pada pemeriksaan ini; tetap cek `df -h` sebelum ekspor.
- Validator ada: `scripts/backup-health.mjs` (hash, copy, restore) dan `scripts/dev-uat-backup-gate.mjs` (tambahan waktu minimum + proyek yang tepat).

## Tindakan operator — tidak otomatis dijalankan

1. Di Supabase Dashboard proyek POS **development**, buka panel **Connect** untuk memperoleh opsi koneksi PostgreSQL yang benar. Pilih **direct** atau **session pooler** yang kompatibel dengan `pg_dump`. Jangan asumsikan alamat pooler atau password. Jangan gunakan transaksi pooler yang tidak mendukung kebutuhan dump.
2. **Jangan kirim** password, connection string, access token, service-role key, data pribadi, atau arsip backup ke chat/GitHub. Jalankan proses dari terminal tepercaya dengan prompt password interaktif. Hindari password di command line atau log; gunakan `PGPASSFILE` dengan mode 0600 yang dibersihkan setelah penggunaan jika memang diperlukan.
3. Buat folder privat di luar repo/Git dengan `umask 077`. Ekspor PostgreSQL logical **custom format** menggunakan `pg_dump -Fc`, PostgreSQL client yang kompatibel, dan skema yang diperlukan (termasuk `auth`, `private`, `public`, serta `xp_bridge_private` jika masih digunakan). Jangan menyalin kredensial ke file manifest. Pertimbangkan pengecualian payload log transport XP bila sesuai kebutuhan pemulihan yang terdokumentasi. Catat kode keluar dan periksa `pg_restore --list`.
4. Simpan **salinan byte-identik** ke lokasi terpisah dari repo (mis. drive/penyimpanan eksternal yang terlindungi), catat SHA-256 kedua salinan, buat manifest yang mengacu pada project ref `pkynjaqrxhhnnfuaxoqp`.
5. **Pulihkan ke PostgreSQL terisolasi**, bukan database POS development aktif, dan verifikasi skema serta baris penting. `pg_restore --list` **bukan** bukti restore berhasil. Jika membutuhkan klaster lokal, siapkan sandbox Postgres terpisah yang secara teknis kompatibel terlebih dahulu.
6. Tuliskan `restore-verification.json` hanya setelah restore selesai dan jumlah baris penting diverifikasi; jangan mengisi `status: PASS` secara fiktif. Simpan log pemulihan tanpa data rahasia.
7. Jalankan gerbang:
   ```bash
   node scripts/backup-health.mjs /lokasi/backup-bundle /lokasi-salinan/backup.dump

   node scripts/dev-uat-backup-gate.mjs \
     --bundle-dir /lokasi/backup-bundle \
     --retained-copy /lokasi-salinan/backup.dump \
     --baseline-utc 2026-10-09T16:52:00Z \
     --project-ref pkynjaqrxhhnnfuaxoqp
   ```

`baseline-utc` contoh di atas mengacu pada inventaris awal database. Untuk UAT berikutnya, gunakan waktu minimum yang memang sesuai dengan titik data sebelum pengujian dan jangan mengecilkan tanggal demi meluluskan backup lama.

Bahkan bila gerbang mengembalikan `BACKUP_EVIDENCE_PRESENT_REVIEW_REQUIRED`, properti `uat_mutations_allowed` **tetap false**: harus ada pemeriksaan manusia atas restore nyata, cakupan skema, kredensial, dan otorisasi UAT.

### Contoh struktur metadata — bukan bukti aktual

`backup-manifest.json`:

```json
{
  "format_version": 1,
  "project_ref": "pkynjaqrxhhnnfuaxoqp",
  "created_at": "<actual-UTC-ISO-timestamp>",
  "logical_export": {
    "file": "backup.dump",
    "sha256": "<actual-file-sha256>"
  }
}
```

`restore-verification.json`:

```json
{
  "status": "<actual-PASS-after-isolated-restore>",
  "verified_at": "<actual-UTC-ISO-timestamp>",
  "backup_sha256": "<same-archive-sha256>",
  "method": "<actual-restore-method>"
}
```

**Tidak boleh** memalsukan nilai contoh di atas menjadi status PASS. Validator menolak metadata yang tidak cocok.

## Status F23

- Backup current: **UNVERIFIED**.
- Restore current: **UNVERIFIED**.
- Perubahan database dan transaksi UAT: **HOLD**.
- Staging terpisah untuk **produksi mendatang** masih perlu disiapkan sebelum go-live.
- Tidak ada biaya Supabase baru untuk inspeksi development ini; keperluan kuota penyimpanan backup harus dicek secara nyata.
