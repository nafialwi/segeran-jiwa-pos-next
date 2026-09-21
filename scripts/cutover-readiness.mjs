import { readFileSync } from 'node:fs';
import { pathToFileURL } from 'node:url';

export function evaluateCutoverReadiness(manifest, securityEvidence) {
  const blockers = [];

  if (manifest.p5a_operational_attention !== 'PASS_GLOBAL_EVENT_DRIVEN') {
    blockers.push('P5A operational attention belum locked.');
  }
  if (manifest.p5b_offline_business_mutations !== 'FAIL_CLOSED_ONLINE_ONLY') {
    blockers.push('P5B offline mutation boundary belum locked.');
  }
  if (manifest.p5c_backup_health !== 'HEALTHY') {
    blockers.push('P5C backup health belum HEALTHY.');
  }
  if (manifest.p5c_restore_verification !== 'PASS') {
    blockers.push('P5C restore verification belum PASS.');
  }
  const credentialProtectionAccepted = new Set([
    'ENABLED_VERIFIED',
    'UNAVAILABLE_FREE_PLAN_ACCEPTED_LIMITATION',
  ]);

  if (
    !credentialProtectionAccepted.has(
      securityEvidence.auth_credential_protection,
    )
  ) {
    blockers.push(
      'Auth credential protection belum enabled atau belum didisposisi sebagai batasan plan.',
    );
  }
  if (
    securityEvidence.authenticated_security_definer_review !==
    'CLEAR_OR_ACCEPTED'
  ) {
    blockers.push(
      'Authenticated SECURITY DEFINER advisor findings belum CLEAR_OR_ACCEPTED.',
    );
  }
  if (securityEvidence.connector_v2_custom_auth_negative_tests !== 'PASS') {
    blockers.push('Connector V2 custom agent authentication belum PASS.');
  }
  if (
    securityEvidence.rls_no_policy_direct_grants_to_anon_authenticated !== 0
  ) {
    blockers.push('Direct grants pada tabel RLS-without-policy masih ada.');
  }
  if (manifest.uat_release_candidate !== 'PASS') {
    blockers.push('UAT release candidate belum dikunci.');
  }

  if (manifest.uat_official_status !== 'PASS') {
    blockers.push('Official UAT belum PASS.');
  }

  if (manifest.final_regression_status !== 'PASS') {
    blockers.push('Final post-UAT regression belum PASS.');
  }

  if (manifest.production_automatic_deployment !== false) {
    blockers.push('Automatic Production deployment harus tetap disabled.');
  }

  return { ready: blockers.length === 0, blockers };
}

function main() {
  const manifest = JSON.parse(
    readFileSync('docs/checkpoints/RELEASE_MANIFEST.json', 'utf8'),
  );
  const securityEvidence = JSON.parse(
    readFileSync('docs/checkpoints/P5D_SECURITY_EVIDENCE.json', 'utf8'),
  );
  const result = evaluateCutoverReadiness(manifest, securityEvidence);

  if (!result.ready) {
    console.error('CUTOVER_READY=NO');
    for (const blocker of result.blockers) console.error('- ' + blocker);
    process.exit(1);
  }

  console.log('CUTOVER_READY=YES');
}

if (
  process.argv[1] &&
  import.meta.url === pathToFileURL(process.argv[1]).href
) {
  main();
}
