# UAT Release Candidate - 2026-09-21

## Candidate

Tag: uat-rc-20260921-1

Commit: e844f9b9ad07ca240e1ba4f72a39c6c7aefbb489

Branch source: work/cs06743-patch3-hardening

The tag identifies the immutable application/source candidate to be tested. Later documentation-only commits do not change the candidate source.

## Entry gates

- P5A Operational Health: LOCKED_REMOTE.
- P5B Offline Action Boundaries: LOCKED_REMOTE.
- P5C Backup Health: HEALTHY.
- P5C isolated restore verification: PASS.
- P5D security review: CLEAR_OR_ACCEPTED.
- Pre-UAT canonical regression: 91/91 JavaScript and 205/205 Python PASS.
- format/lint/typecheck/build/git diff check: PASS.
- Production automatic deployment: DISABLED.

## UAT rule

Any source-code fix after this candidate invalidates RC1 and requires a new candidate tag after full regression.

Documentation/evidence updates may continue on the working branch, but official UAT results must always name the exact candidate tag and commit.

## Exit

Official UAT PASS is required before the final post-UAT regression and final cutover acceptance.
