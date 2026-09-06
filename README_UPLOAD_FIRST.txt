SEGERAN JIWA NEXT VOL. 1 — CS-01 TASK 1

Gunakan paket ini HANYA di GitHub Codespaces untuk repo:
https://github.com/nafialwi/segeran-jiwa-pos-next.git

Setelah ZIP di-upload ke root Codespace, jalankan satu command:

unzip -o SEGERAN_JIWA_NEXT_VOL1_CS01_TASK1_CODESPACES_BOOTSTRAP.zip && bash APPLY_CS01_TASK1.sh

Script akan:
- memastikan remote canonical benar;
- membuat/pindah ke work/cs-01;
- memastikan Node 24;
- install + lock dependency;
- menjalankan format/lint/typecheck/Vitest/build/diff-check;
- hanya commit jika semua PASS;
- push work/cs-01 ke GitHub.

Jangan jalankan source implementation di main.
