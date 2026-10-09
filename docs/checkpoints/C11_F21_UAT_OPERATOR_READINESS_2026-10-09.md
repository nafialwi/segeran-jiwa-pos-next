# C11-F21 — UAT Operator Workbook & Safe-Point

Tanggal 2026-10-09. Branch `work/c11e-preuat-readiness-termux`. Parent app source: F20 `0fafee4109c6f9d6f30898aec71cf5514919aee1`.

## Yang selesai pada F21

1. Menyediakan **single-file HTML offline**, mobile-first, pencarian/filter, catatan temuan dan ekspor/impor JSON untuk 44 skenario UAT (27 P0, 17 P1).
2. Semua 44 skenario default **Belum diuji**. Tidak ada status UAT yang diwariskan dari pengujian fixture atau RC4 lama.
3. Workbook hanya menggunakan skrip/style inline, tidak meminta password dan tidak memanggil API server, RPC, jaringan, checkout atau penyimpanan basis data.
4. Penanda gagal P0 memunculkan instruksi STOP dan cutover tetap dilarang. Status semua lulus tetap mensyaratkan verifikasi bukti, regression serta persetujuan manusia.
5. ChromeDriver/Chromium Termux menguji viewport 320, 390, 768 CSS px, tanpa horizontal overflow; status awal 44 pending, localStorage sesudah refresh, FAIL P0, filter status. Screenshot ketiganya berada di `docs/visual-evidence/c11f21/` dan menunjukkan **0 lulus**.
6. Dokumen `docs/uat/UAT_C11_F21_OPERATOR_HANDOFF_2026-10-09.md` menjelaskan langkah penggunaan dan aturan staging.

## Yang sudah terbukti sebelum F21

- F13 login unsigned responsif + logo lebih ringan; F14 pemisahan 26 route; F15 penanganan halaman gagal dimuat.
- F16 Menu/Produksi/Pengguna navigasi; F17–F19 fixture visual Menu/Produksi, Laporan/Riwayat, Keuangan/Shift.
- F20 fixture visual Jual/Keranjang/UI pembayaran di enam viewport, checkout aktual tidak dijalankan.
- F20 canonical CI hijau, 107 JavaScript dan 533 Python pada baseline.

## Status yang tidak boleh dibesar-besarkan

- **UAT terautentikasi akun Owner/Kasir pada commit terkini: BELUM ADA bukti kelulusan baru.** Workbook bukan bukti lulus.
- **UAT riil checkout, penerimaan barang, stok, retur, audit log, backup restore terkini: TERTUNDA.** Semua aksi mutatif wajib staging.
- **Cutover**: `NO`, karena release manifest menunjuk commit lama `c86d4c0...` dan belum ada signoff kandidat baru. Jangan mengubah manifest hanya agar gerbang menjadi hijau.
- Quality gate lokal F21: repo guard PASS, Prettier PASS, ESLint PASS, TypeScript PASS, Vitest 107/107 PASS, Python 538/538 PASS, Vite production build PASS, git diff check PASS. Browser workbook setelah format PASS pada 320/390/768 CSS px. GitHub CI perlu dicek setelah push; tidak ada claim UAT aplikasi telah PASS.

## Estimasi menuju final (planning, bukan sertifikasi)

Mengikuti F20: (45% × 95% implementasi) + (25% × 100% tes otomatis jika lulus) + (10% × 80% browser fixture) + (15% × 0% UAT terkini diterima) + (5% × 0% cutover disetujui) = **75,75% ≈ 76%**. Pekerjaan F21 menyiapkan UAT; **angka 76% tidak dinaikkan** sebelum ada bukti UAT yang benar-benar lulus. Manifest `99%` kandidat C10 adalah historis, bukan nilai kandidat terbaru.

## Langkah berikutnya

Jalankan checklist berurutan dengan akun sah. Prioritas P0: autentikasi, shift, checkout-idempotensi, server permission, pembelian/stok, refund/keuangan, backup keamanan. Kumpulkan JSON hasil tanpa rahasia dan tangani temuan, lalu tes ulang, final lock dan persetujuan produksi eksplisit.
