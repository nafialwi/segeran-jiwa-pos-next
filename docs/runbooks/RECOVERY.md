# Recovery — Segeran Jiwa POS Next

## Urutan recovery wajib

Mobile Inbox Automation
→ Codespaces debugging
→ manual GitHub transfer branch
→ Termux/X11
→ PC

Urutan ini tidak boleh dilompati tanpa alasan teknis yang jelas.

## 1. Mobile Inbox Automation

**Normal/default.** Gunakan GitHub Web dari Android untuk upload tepat satu package ZIP ke `mobile-inbox/inbox/`.

Dianggap gagal untuk kasus aktif bila:

- Action tidak dapat memproses package dan failure report membutuhkan debugging;
- dispatcher/worker tidak tersedia atau gagal sebelum menghasilkan diagnosis yang cukup;
- retry normal setelah penyebab yang dipahami tetap tidak menyelesaikan kasus.

Satu Action run gagal **bukan** alasan otomatis pindah ke Termux. Baca report dulu.

## 2. Codespaces debugging

Gunakan Codespaces untuk inspeksi source, tests, logs, atau menjalankan recovery script ketika automation tidak cukup.

Dianggap gagal bila:

- UI/terminal Codespaces tidak dapat digunakan dari perangkat saat itu;
- masalah transfer file ke Codespaces membuat recovery tidak praktis;
- diagnosis sudah jelas tetapi transfer artifact perlu jalur lain.

## 3. Manual GitHub transfer branch

Gunakan branch transfer sementara untuk memindahkan artifact melalui GitHub Web tanpa menjadikan `main` sebagai transit dan tanpa bergantung pada upload file di VS Code/Codespaces.

Aturan:

- branch transfer bukan source canonical;
- jangan merge ZIP transit ke `main`;
- setelah artifact diambil/diterapkan, pekerjaan canonical tetap berada di `work/**`.

Dianggap gagal bila:

- GitHub Web tidak dapat mengunggah/commit artifact;
- artifact tidak dapat diambil dari branch transfer;
- kasus memerlukan shell/device workflow yang tidak tersedia melalui transfer branch.

## 4. Termux/X11

Gunakan Termux/X11 hanya setelah tiga jalur di atas tidak cukup. Cocok untuk SSH/Codespace terminal, pemeriksaan command-line, atau recovery teknis yang memang membutuhkan shell.

Dianggap gagal bila:

- tool/auth/network lokal tidak memadai;
- debugging membutuhkan lingkungan desktop/PC penuh.

## 5. PC

Fallback terakhir untuk kasus yang tidak praktis diselesaikan dari HP.

## Safety rules

- Jangan gunakan `main` sebagai tempat transit ZIP.
- Jangan force-push branch canonical hanya untuk mempercepat recovery.
- Jangan mengubah Production karena intake/recovery tanpa release approval.
- Jangan membuat success receipt jika verification gagal.
- Jangan retry package sukses dengan content berbeda memakai `package_id` yang sama.
