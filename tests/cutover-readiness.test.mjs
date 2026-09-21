import { describe, expect, it } from 'vitest';
import { evaluateCutoverReadiness } from '../scripts/cutover-readiness.mjs';

function goodManifest() {
  return {
    p5a_operational_attention: 'PASS_GLOBAL_EVENT_DRIVEN',
    p5b_offline_business_mutations: 'FAIL_CLOSED_ONLINE_ONLY',
    p5c_backup_health: 'HEALTHY',
    p5c_restore_verification: 'PASS',
    uat_release_candidate: 'PASS',
    uat_official_status: 'PASS',
    final_regression_status: 'PASS',
    production_automatic_deployment: false,
  };
}

function goodSecurity() {
  return {
    auth_credential_protection: 'UNAVAILABLE_FREE_PLAN_ACCEPTED_LIMITATION',
    authenticated_security_definer_review: 'CLEAR_OR_ACCEPTED',
    connector_v2_custom_auth_negative_tests: 'PASS',
    rls_no_policy_direct_grants_to_anon_authenticated: 0,
  };
}

describe('P5D cutover readiness gate', () => {
  it('accepts a fully proven final-hardening state', () => {
    const result = evaluateCutoverReadiness(goodManifest(), goodSecurity());
    expect(result.ready).toBe(true);
    expect(result.blockers).toEqual([]);
  });

  it('accepts the documented Free-plan credential-protection limitation', () => {
    const result = evaluateCutoverReadiness(goodManifest(), goodSecurity());
    expect(result.ready).toBe(true);
  });

  it('fails closed while backup evidence is incomplete', () => {
    const manifest = goodManifest();
    manifest.p5c_backup_health = 'UNHEALTHY_FAIL_CLOSED';
    manifest.p5c_restore_verification = 'MISSING';
    const result = evaluateCutoverReadiness(manifest, goodSecurity());
    expect(result.ready).toBe(false);
    expect(result.blockers.join('\n')).toContain('backup health');
    expect(result.blockers.join('\n')).toContain('restore verification');
  });

  it('fails closed on unresolved security follow-up', () => {
    const security = goodSecurity();
    security.auth_credential_protection = 'DISABLED_OPEN';
    security.authenticated_security_definer_review = 'OPEN';
    const result = evaluateCutoverReadiness(goodManifest(), security);
    expect(result.ready).toBe(false);
    expect(result.blockers.join('\n')).toContain('credential protection');
    expect(result.blockers.join('\n')).toContain('SECURITY DEFINER');
  });

  it('fails closed if connector custom authentication regresses', () => {
    const security = goodSecurity();
    security.connector_v2_custom_auth_negative_tests = 'FAIL';
    const result = evaluateCutoverReadiness(goodManifest(), security);
    expect(result.ready).toBe(false);
    expect(result.blockers.join('\n')).toContain('Connector V2');
  });

  it('fails closed until UAT and final regression are complete', () => {
    const manifest = goodManifest();
    manifest.uat_release_candidate = 'NOT_CREATED';
    manifest.uat_official_status = 'NOT_STARTED';
    manifest.final_regression_status = 'NOT_RUN';

    const result = evaluateCutoverReadiness(manifest, goodSecurity());

    expect(result.ready).toBe(false);
    expect(result.blockers.join('\n')).toContain('UAT release candidate');
    expect(result.blockers.join('\n')).toContain('Official UAT');
    expect(result.blockers.join('\n')).toContain('Final post-UAT regression');
  });

  it('requires automatic Production deployment to stay disabled', () => {
    const manifest = goodManifest();
    manifest.production_automatic_deployment = true;
    const result = evaluateCutoverReadiness(manifest, goodSecurity());
    expect(result.ready).toBe(false);
    expect(result.blockers.join('\n')).toContain('Production deployment');
  });
});
