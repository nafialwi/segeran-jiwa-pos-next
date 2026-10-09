# F21 — Panduan Pelaksanaan UAT Segeran Jiwa POS Next

Tanggal: 9 Oktober 2026. Branch: `work/c11e-preuat-readiness-termux`.
Baseline aplikasi yang dipakai menyusun skenario: `0fafee4109c6f9d6f30898aec71cf5514919aee1` (F20). File F21 hanya menambahkan workbook, pengujian workbook, dokumentasi, dan bukti screenshot; **tidak mengganti alur bisnis aplikasi**.

## Apa yang tersedia

- [Workbook HTML offline](./UAT_C11_F21_OPERATOR_WORKBOOK_2026-10-09.html): 44 skenario, status awal `Belum diuji`, pencarian/filter, catatan, ringkasan, ekspor/impor JSON.
- Pengelompokan: Akun (5), Kasir (15), Owner (11), Keamanan (5), Perangkat (4), Rilis (4). Sebanyak 27 tes P0 dan 17 tes P1; prioritas berarti tingkat konsekuensi jika gagal, **bukan** bukti bahwa sistem saat ini mengalami 27 masalah.
- Hasil audit teknis HTML/ChromeDriver disimpan sebagai bukti **alat UAT berfungsi**, bukan 44 skenario aplikasi sudah lulus.

## Cara pakai di Android

1. Ambil file HTML dari GitHub branch ini (gunakan unduhan **Raw**, bukan tampilan kode) dan buka memakai browser Android. Tidak perlu koneksi setelah file dibuka.
2. Gunakan akun Owner/Kasir uji dan lingkungan **staging / nonproduksi** yang disetujui. Jangan menguji mutasi uang, stok, refund atau izin pada data produksi tanpa persetujuan khusus.
3. Ketika suatu langkah benar-benar dijalankan, pilih `Lulus`, `Gagal`, atau `Terblokir`. Biarkan `Belum diuji` bila tidak ada bukti.
4. Isi catatan singkat dan ID bukti yang tidak sensitif; jangan tuliskan password, token, nomor pribadi, atau data pelanggan asli.
5. Simpan hasil menggunakan **Ekspor hasil JSON**. File tersimpan di perangkat, tidak terkirim otomatis. Gunakan **Impor hasil JSON** untuk melanjutkan hasil pada browser yang berbeda.
6. Jika terjadi kegagalan P0, hentikan persetujuan rilis sampai diperbaiki dan diverifikasi ulang. Status hijau pada workbook pun **tidak menggantikan** security review dan persetujuan produksi eksplisit.

Perhatian: penyimpanan browser untuk `file://` bisa berbeda-beda. Fitur ekspor adalah cadangan yang disarankan. JSON hasil sengaja memuat `releaseApproved: false`.

## Urutan pelaksanaan yang efisien

Prioritaskan Akun dan Kasir pada Android; kemudian Owner (produk, pembelian, persediaan, produksi, laporan, keuangan), uji negatif akses Kasir, dan uji perangkat. Skenario rilis G01–G04 dilaksanakan setelah semua temuan P0/P1 ditutup.

### Gerbang penerimaan

- Kandidat preview, commit dan lingkungan harus diverifikasi sebelum mulai UAT.
- Seluruh skenario penting diuji dengan **bukti tindakan nyata**, tanpa P0/P1 yang masih terbuka. P2/P3, bila ada, perlu disposisi yang disetujui.
- Skenario idempotensi K12: **satu operasi menghasilkan satu invoice dan satu efek stok**. Jangan mensimulasikan kegagalan jaringan di lingkungan produksi.
- Role check S01/S02 tidak cukup dari tombol UI; verifikasi penolakan di server menggunakan akun uji dengan izin terbatas.
- Jalankan ulang seluruh tes otomatis, validasi backend keamanan/backup terbaru, dan bandingkan manifest rilis dengan **commit immutable final**.
- Persetujuan manusia dan keputusan deployment dilakukan secara terpisah. Sampai saat itu: `CUTOVER_READY=NO`.

## Yang belum dilakukan oleh checkpoint ini

Tidak ada login Owner/Kasir nyata, checkout atau stok riil, akses database, perubahan RLS, migrasi, promosi branch, atau deployment produksi. Workbook adalah **alat bantu pengumpulan bukti UAT** agar pengujian yang sebelumnya tertunda dapat dikerjakan tanpa mencatat keberhasilan palsu.
