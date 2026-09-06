# Release Guard — CS-01

## GitHub mode

`RELEASE_GUARD_MODE=PROCESS-GUARD`

Repository remains private.

GitHub UI evidence for the current account states that repository rulesets are not enforced on this private repository unless moved to a GitHub Team organization account.

No paid upgrade is authorized for CS-01.

Residual risk:

- repository Owner technically retains direct-push capability;
- normal workflow and automation must never write to `main` before explicit Owner approval.

## Required process guard

- package ZIP transit on `main` is forbidden;
- verified source changes go to `work/**`;
- `canonical-verify: success` is required before approval;
- normal source promotion uses PR review;
- force-push to canonical history is not part of normal workflow;
- Cloudflare automatic Production branch deployment is disabled;
- Preview remains enabled for non-Production branches.

## Zero-cost guard

- repository remains private;
- GitHub Actions uses standard Linux runners;
- no paid runner is enabled;
- no paid GitHub or Cloudflare upgrade is authorized automatically;
- if included provider capacity is exhausted, automation may stop rather than silently incur cost;
- provider limits must be revalidated before Production.
