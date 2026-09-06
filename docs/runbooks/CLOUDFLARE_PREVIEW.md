# Cloudflare Preview — CS-01

## Project

- Cloudflare Pages project: `segeran-jiwa-pos-next`
- Canonical Pages domain: `segeran-jiwa-pos-next.pages.dev`
- Git repository: `nafialwi/segeran-jiwa-pos-next`
- Production branch: `main`
- Build command: `npm run build`
- Build output directory: `dist`

## Branch deployment policy

Production:

- branch: `main`
- automatic Production branch deployments: **DISABLED**

Preview:

- automatic Preview deployments: **ENABLED**
- branch policy: **All non-Production branches**

Therefore normal `work/**` development may create Preview deployments for QA while an inbox upload or working-branch push cannot automatically change Production.

## CS-01 Preview acceptance

Preview must display:

- `Segeran Jiwa POS Next`
- `CS-01 — Foundation`

Before milestone approval confirm:

- working branch has `canonical-verify: success`;
- Preview corresponds to the intended working commit;
- `main` remains unchanged by the Preview build;
- Production remains unchanged.
