# P5D Security & Cutover Gate Safepoint

Date: 2026-09-21

## Verdict

**PREPARED_SAFE / CUTOVER BLOCKED**

This checkpoint prepares a deterministic final cutover gate but does not authorize Production cutover.

## Live security review

The Supabase security advisor reported:

- 10 INFO findings: RLS enabled with no policy;
- 4 WARN findings: anonymous role can execute Connector V2 SECURITY DEFINER RPCs;
- 60 WARN findings: authenticated users can execute SECURITY DEFINER RPCs;
- 1 WARN finding: auth credential protection is disabled.

### RLS-without-policy findings

The 10 flagged tables have no direct table grants to anon or authenticated according to information_schema.role_table_grants at review time.

This means the INFO findings do not by themselves prove an exposed table path, but they remain documented security evidence.

### Connector V2 anonymous SECURITY DEFINER warnings

The four Connector V2 RPCs are intentionally callable with the anon Supabase key because the PC workers use an independent x-agent-token control.

Every V2 RPC immediately invokes xp_bridge_private.authorize_agent.

The private authorizer:

- rejects a missing x-agent-token;
- rejects a wrong x-agent-token;
- requires the requested agent ID to exist and be enabled;
- hashes the supplied token with SHA-256;
- compares only against the stored SHA-256 value;
- is not executable directly by public, anon, or authenticated.

Live negative authentication tests for missing and wrong tokens: PASS.

Agent registry review:

- enabled agents: 4;
- valid SHA-256 token hashes: 4;
- invalid token hashes: 0.

The generic linter warning remains because it cannot infer this custom header authorization design. The warning is reviewed, not silently ignored.

### Authenticated SECURITY DEFINER findings

The 60 findings require a bounded final review to distinguish intentionally exposed permission-checked business RPCs from any function that should have execute revoked.

Until that review is complete, cutover remains blocked.

### Auth credential protection

The security advisor reports the protection as disabled.

This remains an explicit cutover blocker until enabled and re-verified.

## Cutover gate

scripts/cutover-readiness.mjs reports CUTOVER_READY=YES only when all required final evidence is true:

- P5A operational attention locked;
- P5B offline business mutation boundary locked;
- P5C backup health HEALTHY;
- P5C restore verification PASS;
- auth credential protection ENABLED_VERIFIED;
- authenticated SECURITY DEFINER findings CLEAR_OR_ACCEPTED;
- Connector V2 custom authentication negative tests PASS;
- zero direct anon/authenticated grants on the reviewed RLS-without-policy tables;
- automatic Production deployment remains disabled until explicit acceptance.

The current repository state must report CUTOVER_READY=NO.

## Current blockers

1. P5C real logical export is missing.
2. P5C retained copy is missing.
3. P5C isolated restore verification is missing.
4. Auth credential protection is disabled.
5. The 60 authenticated SECURITY DEFINER advisor findings are not yet fully dispositioned.

## Verification

Feature commit: 96b9003fb4c59bbf846eec3812f31a7a03a36491

Canonical verification after the gate implementation:

- JavaScript: 89/89 PASS;
- Python: 205/205 PASS;
- format check: PASS;
- lint: PASS;
- typecheck: PASS;
- production build: PASS;
- git diff --check: PASS;
- current cutover check: expected fail-closed with four explicit blockers.

## Safety boundary

No hosted schema or business data was changed by this checkpoint.

No Production deployment was performed.

Automatic Production deployment remains disabled.

## Progress accounting

P5A and P5B remain LOCKED_REMOTE.

P5C Backup Health Gate remains PREPARED_SAFE and fail-closed.

P5D Security & Cutover Gate is PREPARED_SAFE and fail-closed.

Whole-project earned progress therefore remains 95.0% until the final hardening acceptance gate is actually clear.
