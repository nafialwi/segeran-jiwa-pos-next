# WORKFLOW PROFILE — Segeran Jiwa POS Next

## Primary workflow setelah CS-04

**Perangkat utama:** Android phone + Termux/X11 + Expert Workstation (XP).

**Manual work normal:** MINIMAL (XP automates execution, verification, and evidence collection).

```text
AI (Qwen/GPT) membuat spec.json (declarative blueprint)
        ↓
User simpan spec.json di Termux
        ↓
XP pkg-build (validate fingerprint, build zip, checksum)
        ↓
User scan via menu [2] (XP inbox)
        ↓
XP apply package (atomic, with backup)
        ↓
XP verify (repo-guard, format, lint, typecheck, test, build, diff-check)
        ↓
XP safepoint (git commit + push ke branch kerja)
        ↓
XP berhenti di HUMAN_QA (menunggu review manusia)
        ↓
User QA manual (uji fungsi, refresh, pastikan tidak ada regression)
        ↓
User approve QA CLEAR di menu XP
        ↓
XP Final Lock (checkpoint + source archive + SHA256 + lease release)
        ↓
Milestone LOCKED_REMOTE (evidence tersimpan di ~/.expert-workstation/checkpoints/)
```

## Environment responsibilities

- **Termux/X11**: Primary workstation (XP runs here, local execution, offline-first)
- **Expert Workstation (XP)**: Workflow authority, execution engine, verification, recovery, evidence
- **AI (Qwen/GPT)**: Architecture, audit, coding, spec generation (declarative packages only)
- **GitHub**: Remote backup, collaboration, recovery (via XP control-repo)
- **Supabase**: Backend/data authority (PostgreSQL)
- **Cloudflare Pages**: Preview/Production frontend (future, after cutover hardening)

## Fallback order

1. **XP on Termux/X11** (primary, automated, offline-capable)
2. **XP handoff to new AI** (jika AI session habis, gunakan `xp handoff --format xp-bundle` untuk migrasi context ke AI baru)
3. **Manual GitHub transfer** (jika XP tidak tersedia, fallback ke upload manual via GitHub Web ke branch `mobile-inbox`)
4. **Codespaces debugging** (jika automation tidak bisa menyelesaikan kasus kompleks)
5. **PC** (fallback/kenyamanan opsional)

## Rules

- **XP sebagai otoritas eksekusi**: AI hanya boleh mengirim spec.json (declarative), XP yang execute dengan safety gates
- **Jangan merge ke main**: Semua pekerjaan di branch `work/*`, merge hanya setelah Final Lock + explicit approval
- **Jangan deploy production**: Production membutuhkan release gate terpisah (belum diimplementasi, see deployment_status: UNVERIFIED_DISABLED)
- **Setiap checkpoint/handoff wajib membawa dokumen ini atau snapshot versinya**: Blueprint ini adalah konstitusi workflow, harus ikut setiap perpindahan context
- **Evidence before assertion**: XP tidak menebak, XP melaporkan bukti (verify_log, git_diff, checkpoint artifacts)
- **Offline-first**: XP dirancang untuk bekerja tanpa internet, sync ke remote saat koneksi tersedia

## Amandemen CS-04 (2026-09-11)

**Perubahan**: Termux/X11 + XP dipromosikan dari "fallback ke-4" menjadi "primary workflow"

**Alasan sistem** (bahasa universal, applicable untuk AI manapun):

1. **Eliminasi manual upload bottleneck**: Workflow lama (AI → ZIP → GitHub Web → Actions) membutuhkan ~100 copy-paste cycles untuk milestone CS-03→CS-04 karena setiap error mengharuskan restart session dan resend context. XP automates ini dengan declarative spec + local execution.

2. **Deterministic execution with safety gates**: XP menerapkan defense-in-depth (package validation, checksum verification, scope enforcement, atomic apply with rollback, crash-safe journal, remote lease protection). AI tidak pernah menyentuh filesystem langsung, hanya mengirim cetak biru deklaratif.

3. **Full audit trail**: Setiap milestone terkunci dengan checkpoint artifacts (CHECKPOINT.md, SOURCE.zip, SHA256SUMS.txt, CHECKPOINT_STATE.json) yang bisa diverifikasi kapan pun tanpa bergantung pada AI session.

4. **Offline capability**: XP berjalan di Termux tanpa internet, sync ke GitHub control-repo saat koneksi tersedia. Ini critical untuk mobile-first development di daerah dengan connectivity tidak stabil.

5. **AI portability**: Jika AI session habis atau user pindah ke AI lain, XP menyediakan `xp handoff --format xp-bundle` yang mengemas entire context (XP source, project state, policies, blueprint snapshot) dalam format yang bisa di-paste ke AI baru. Ini menghilangkan vendor lock-in.

6. **Multi-project support**: XP dirancang untuk handle 10-100 project berbeda secara concurrent, masing-masing di chat/terminal terpisah. Registry-based architecture memungkinkan switching antar project tanpa context loss.

**Bukti efektivitas**: CS-04-CLOSURE (2026-09-11) terkunci dalam ~5 interaksi (spec → pkg-build → scan → verify → QA → lock), dibandingkan ~100 interaksi manual di CS-03.

## Handoff protocol untuk AI migration

Jika AI session habis atau user ingin pindah ke AI lain:

1. **Jalankan**: `xp handoff --repo <project-path> --format xp-bundle`
2. **Output**: File `.txt` berisi:
   - XP version + source code (key modules: autopilot, executor, packages, adapters)
   - Current project state (RunState, policies, compatibility, roadmap progress)
   - Blueprint snapshot (file ini)
   - Latest checkpoint report (jika ada)
3. **Paste ke AI baru**: Upload file `.txt` atau copy-paste isinya
4. **AI baru baca**: Context lengkap, tidak perlu re-explain arsitektur XP dari nol
5. **Lanjutkan pekerjaan**: AI baru bisa langsung generate spec.json untuk milestone berikutnya

**Contoh command**:
```bash
xp handoff --repo ~/WORKSTATION/projects/segeran-jiwa-pos-next --format xp-bundle
# Output: ~/storage/downloads/Expert/XP_BUNDLE_segeran-jiwa-pos-next_2026-09-11.txt
# Upload file ini ke AI baru, atau:
cat ~/storage/downloads/Expert/XP_BUNDLE_segeran-jiwa-pos-next_2026-09-11.txt | termux-clipboard-set
# Paste ke chat AI baru
```

## Version history

- **v1.0** (pre-CS-04): Primary workflow = Mobile Inbox Automation (GitHub Web + Actions)
- **v1.1** (2026-09-11, CS-04 lock): Primary workflow = XP on Termux/X11, Mobile Inbox demoted to fallback #3

## Continuity snapshot v1.0 (pre-CS-04, dipertahankan untuk guard test dan handoff lama)

**Perangkat utama:** Android phone + browser.

**Manual work normal:** LOW.

```text
ChatGPT membuat package ZIP
        ↓
User upload 1 ZIP melalui GitHub Web
        ↓
branch permanen: mobile-inbox
        ↓
GitHub Actions Intake
        ↓
Validasi manifest / checksum / baseline / path
        ↓
Apply ke working branch
        ↓
Lint + Typecheck + Test + Build + Guards
        ↓
Create/Update PR
        ↓
Cloudflare Preview
        ↓
Real-device QA user
        ↓
Explicit approval pada gate
        ↓
Merge / Release / Production sesuai stage
```

### Environment responsibilities (legacy)

- **GitHub Web:** upload package dari HP.
- **mobile-inbox:** kotak masuk package, bukan source production.
- **GitHub Actions:** intake, validation, verify, PR automation.
- **Codespaces:** debugging/recovery jika automation tidak bisa menyelesaikan kasus.
- **Termux/X11:** fallback.
- **PC:** fallback/kenyamanan opsional.
- **Cloudflare Pages:** Preview/Production frontend.
- **Supabase:** backend/data authority.

### Fallback order (legacy)

1. Mobile Inbox Automation.
2. Codespaces debugging.
3. Manual GitHub transfer branch bila intake unavailable.
4. Termux/X11.
5. PC.

### Rules (legacy)

- Jangan upload package transit ke `main`.
- Jangan meminta user membuka Termux sebagai default.
- Jangan memberi belasan command jika dapat disatukan menjadi project script/CI.
- Production membutuhkan release gate/approval; upload ZIP tidak boleh langsung production.
- Setiap checkpoint/handoff wajib membawa dokumen ini atau snapshot versinya.
