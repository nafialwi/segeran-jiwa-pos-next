# P5D2 Authenticated SECURITY DEFINER Review Checkpoint

Date: 2026-09-21

## Verdict

**CLEAR_OR_ACCEPTED / SAFE**

The complete live set of SECURITY DEFINER functions executable by the authenticated role was reviewed before this checkpoint was locked.

## Live inventory

The hosted project exposed exactly 60 public SECURITY DEFINER functions to the authenticated role.

Additional execution-surface checks:

- 60/60 use an empty function search_path;
- 0/60 are also executable by anon;
- 0/60 remained unclassified after the bounded guard review.

## Guard disposition

All 60 functions fell into an explicit bounded category:

- AUTH_UID_GATE: 1;
- AUTHORITY_PROJECTION: 1;
- BUSINESS_AUTHORITY_GATE: 2;
- COMPOSED_GUARDED_COMMANDS: 1;
- DISABLED_FAIL_CLOSED: 1;
- EXPLICIT_PERMISSION_GATE: 24;
- OWNER_AUTHORITY_GATE: 7;
- OWNER_GATE: 17;
- SELF_SESSION_GATE: 1;
- SHIFT_PERMISSION_GATE: 5.

The classifications sum to 60.

Accepted patterns include explicit permission checks, Owner-only helpers, shift-permission helpers, business-authority matching, self-session scoping, and a direct-buy composition that delegates into already guarded purchase commands.

The legacy cash-movement command remains fail-closed by design.

## Connector V2

Connector V2 is not part of the 60 authenticated findings. Its four anonymous SECURITY DEFINER RPCs use independent x-agent-token authentication.

Missing-token and wrong-token live negative tests remain PASS.

## Auth credential protection plan limitation

Supabase documentation confirms that leaked password protection is available on the Pro plan and above.

The hosted project is on the Free plan.

For the zero-cost release path this advisor finding is therefore recorded as:

**UNAVAILABLE_FREE_PLAN_ACCEPTED_LIMITATION**

This is not represented as enabled. It is an explicit platform limitation and remains visible in security evidence.

## Security result

Authenticated SECURITY DEFINER review: **CLEAR_OR_ACCEPTED**

Auth credential protection: **UNAVAILABLE_FREE_PLAN_ACCEPTED_LIMITATION**

P5D security review can therefore close without pretending that the Pro-only setting is enabled.

Final cutover still requires P5C backup health and restore evidence.

## Safety boundary

No hosted function, grant, policy, schema object, or business row was changed during this review.

Automatic Production deployment remains disabled.
