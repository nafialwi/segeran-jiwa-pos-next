# WORKFLOW PROFILE — Segeran Jiwa POS Next

## Primary workflow setelah CS-01

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

## Environment responsibilities

- **GitHub Web:** upload package dari HP.
- **mobile-inbox:** kotak masuk package, bukan source production.
- **GitHub Actions:** intake, validation, verify, PR automation.
- **Codespaces:** debugging/recovery jika automation tidak bisa menyelesaikan kasus.
- **Termux/X11:** fallback.
- **PC:** fallback/kenyamanan opsional.
- **Cloudflare Pages:** Preview/Production frontend.
- **Supabase:** backend/data authority.

## Fallback order

1. Mobile Inbox Automation.
2. Codespaces debugging.
3. Manual GitHub transfer branch bila intake unavailable.
4. Termux/X11.
5. PC.

## Rules

- Jangan upload package transit ke `main`.
- Jangan meminta user membuka Termux sebagai default.
- Jangan memberi belasan command jika dapat disatukan menjadi project script/CI.
- Production membutuhkan release gate/approval; upload ZIP tidak boleh langsung production.
- Setiap checkpoint/handoff wajib membawa dokumen ini atau snapshot versinya.
