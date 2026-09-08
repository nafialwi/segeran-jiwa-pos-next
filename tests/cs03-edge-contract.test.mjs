import { describe, expect, it } from 'vitest';
import { existsSync, readFileSync, readdirSync, statSync } from 'node:fs';
import { join } from 'node:path';

function filesUnder(root) {
  const out = [];
  if (!existsSync(root)) return out;
  for (const name of readdirSync(root)) {
    const path = join(root, name);
    if (statSync(path).isDirectory()) out.push(...filesUnder(path));
    else out.push(path);
  }
  return out;
}

function textUnder(root) {
  return filesUnder(root)
    .map((path) => readFileSync(path, 'utf8'))
    .join('\n');
}

const requiredEdgeFiles = [
  'supabase/functions/_shared/admin-clients.ts',
  'supabase/functions/_shared/auth-context.ts',
  'supabase/functions/_shared/http.ts',
  'supabase/functions/_shared/identity.ts',
];

describe('CS-03 secret boundary', () => {
  it('never reads server secret keys from browser source', () => {
    const text = textUnder('src');
    expect(text).not.toContain('SUPABASE_SECRET_KEYS');
    expect(text).not.toContain('SUPABASE_SERVICE_ROLE_KEY');
    expect(text).not.toContain('sb_secret_');
  });

  it('keeps Auth admin APIs inside Edge Functions', () => {
    const browser = textUnder('src');
    expect(browser).not.toContain('auth.admin.');
  });
});

describe('CS-03 Edge auth primitives', () => {
  it('provides every required shared primitive file', () => {
    for (const path of requiredEdgeFiles) {
      expect(existsSync(path), path).toBe(true);
    }
  });

  it('keeps secret and publishable keys in the Edge environment', () => {
    const text = readFileSync(
      'supabase/functions/_shared/admin-clients.ts',
      'utf8',
    );
    expect(text).toContain("Deno.env.get('SUPABASE_URL')");
    expect(text).toContain("defaultKey('SUPABASE_SECRET_KEYS')");
    expect(text).toContain("defaultKey('SUPABASE_PUBLISHABLE_KEYS')");
    expect(text).toContain('persistSession: false');
    expect(text).toContain('autoRefreshToken: false');
  });

  it('validates bearer user first, then binds authority to JWT session', () => {
    const text = readFileSync(
      'supabase/functions/_shared/auth-context.ts',
      'utf8',
    );
    const getUser = text.indexOf('auth.getUser(token)');
    const sessionDecode = text.indexOf('payload.session_id');

    expect(text).toContain('Authorization');
    expect(getUser).toBeGreaterThan(-1);
    expect(sessionDecode).toBeGreaterThan(getUser);
    expect(text).toContain("rpc('get_my_authority')");
    expect(text).toContain('authority.owner !== true');
    expect(text).toContain('createAdminClient()');
    expect(text).not.toContain('body.actor');
    expect(text).not.toContain('body.business');
    expect(text).not.toContain('body.session');
  });

  it('returns only a safe JSON envelope', () => {
    const text = readFileSync('supabase/functions/_shared/http.ts', 'utf8');
    expect(text).toContain('ok: true');
    expect(text).toContain('ok: false');
    expect(text).toContain('code');
    expect(text).toContain('message');
    expect(text).not.toContain('.stack');
    expect(text).not.toContain('postgres');
  });

  it('matches the browser and database username/password contract', () => {
    const text = readFileSync('supabase/functions/_shared/identity.ts', 'utf8');
    expect(text).toContain('trim().toLowerCase()');
    expect(text).toContain('^[a-z0-9][a-z0-9_-]{2,31}$');
    expect(text).toContain('auth.segeranjiwa.invalid');
    expect(text).toContain('password.length < 8');
    expect(text).toContain('password.length > 72');
    expect(text).toContain('toInternalAuthEmail');
    expect(text).toContain('validateStaffPassword');
  });
});
describe('CS-03 Owner staff lifecycle', () => {
  const identityAdminPath = 'supabase/functions/identity-admin/index.ts';
  const ownerScreenPath = 'src/screens/OwnerUsersScreen.tsx';
  const appPath = 'src/App.tsx';

  it('keeps staff Auth admin work inside the Owner-only Edge handler', () => {
    expect(existsSync(identityAdminPath)).toBe(true);
    const text = readFileSync(identityAdminPath, 'utf8');

    expect(text).toContain('requireOwnerContext(req)');
    expect(text).toContain("action === 'create_staff'");
    expect(text).toContain("action === 'reset_password'");
    expect(text).toContain("action === 'set_status'");
    expect(text).toContain("action === 'set_permission'");

    expect(text).toContain('auth.admin.createUser');
    expect(text).toContain('auth.admin.updateUserById');
    expect(text).toContain('cs03_admin_bind_staff');
    expect(text).toContain('cs03_admin_get_target_auth_user');
    expect(text).toContain('cs03_admin_record_password_reset');
    expect(text).toContain('cs03_admin_set_status');
    expect(text).toContain('cs03_admin_set_permission_override');

    expect(text).toContain('auth.admin.deleteUser');
    expect(text).toContain('newAuthUser.id');

    expect(text).not.toContain('change_username');
    expect(text).not.toContain('console.log(password');
    expect(text).not.toContain('console.log(body');
    expect(text).not.toContain('internal_email');
  });

  it('creates users before binding and compensates only the new unbound principal', () => {
    const text = readFileSync(identityAdminPath, 'utf8');
    const createIndex = text.indexOf('auth.admin.createUser');
    const bindIndex = text.search(/rpc\(\s*'cs03_admin_bind_staff'/);
    const deleteIndex = text.indexOf('auth.admin.deleteUser(newAuthUser.id)');

    expect(createIndex).toBeGreaterThan(-1);
    expect(bindIndex).toBeGreaterThan(createIndex);
    expect(deleteIndex).toBeGreaterThan(bindIndex);
  });

  it('resets password through target lookup, Auth admin update and audit RPC', () => {
    const text = readFileSync(identityAdminPath, 'utf8');
    const lookupIndex = text.indexOf("rpc('cs03_admin_get_target_auth_user'");
    const updateIndex = text.indexOf('auth.admin.updateUserById');
    const auditIndex = text.indexOf("'cs03_admin_record_password_reset'");

    expect(lookupIndex).toBeGreaterThan(-1);
    expect(updateIndex).toBeGreaterThan(lookupIndex);
    expect(auditIndex).toBeGreaterThan(updateIndex);
  });

  it('provides Owner UI without email or username-edit surfaces', () => {
    expect(existsSync(ownerScreenPath)).toBe(true);
    const text = readFileSync(ownerScreenPath, 'utf8');

    expect(text).toContain("rpc('owner_list_users')");
    expect(text).toMatch(/functions\.invoke\(\s*'identity-admin'/);
    expect(text).toContain('refreshAuthority()');

    expect(text).toContain('Aktif');
    expect(text).toContain('Cuti');
    expect(text).toContain('Dinonaktifkan');
    expect(text).toContain('Catat Pengeluaran Shift');

    expect(text).not.toContain('internal email');
    expect(text).not.toContain('internal_email');
    expect(text).not.toContain('Ubah Username');
    expect(text).not.toContain('change_username');
  });

  it('wires the Owner-only /pengguna route to OwnerUsersScreen', () => {
    const text = readFileSync(appPath, 'utf8');
    expect(text).toContain('import { OwnerUsersScreen }');
    expect(text).toContain('<OwnerUsersScreen />');
    expect(text).toContain('<RequireAccess ownerOnly>');
  });
});
describe('CS-03 Owner device/session governance', () => {
  const deviceAdminPath = 'supabase/functions/device-admin/index.ts';
  const ownerScreenPath = 'src/screens/OwnerUsersScreen.tsx';
  const migrationPath =
    'supabase/migrations/20260908013000_cs03_identity_session_permission.sql';

  it('provides Owner-only revoke, remove, combined and rename actions', () => {
    expect(existsSync(deviceAdminPath)).toBe(true);
    const text = readFileSync(deviceAdminPath, 'utf8');

    expect(text).toContain('requireOwnerContext(req)');
    expect(text).toContain("action === 'revoke_device'");
    expect(text).toContain("action === 'remove_device'");
    expect(text).toContain("action === 'revoke_and_remove'");
    expect(text).toContain("action === 'rename_device'");

    expect(text).toContain("'cs03_admin_revoke_device'");
    expect(text).toContain("'cs03_admin_remove_device'");
    expect(text).toContain("'cs03_admin_rename_device'");
  });

  it('does not let remove_device silently bypass the revoke prerequisite', () => {
    const text = readFileSync(deviceAdminPath, 'utf8');
    const removeStart = text.indexOf('async function removeDevice');
    const combinedStart = text.indexOf('async function revokeAndRemoveDevice');

    expect(removeStart).toBeGreaterThan(-1);
    expect(combinedStart).toBeGreaterThan(removeStart);

    const removeBlock = text.slice(removeStart, combinedStart);
    expect(removeBlock).toContain("'cs03_admin_remove_device'");
    expect(removeBlock).not.toContain('cs03_admin_revoke_device');

    const migration = readFileSync(migrationPath, 'utf8');
    const dbRemoveStart = migration.indexOf(
      'create or replace function public.cs03_admin_remove_device',
    );
    const dbRenameStart = migration.indexOf(
      'create or replace function public.cs03_admin_rename_device',
    );
    const dbRemoveBlock = migration.slice(dbRemoveStart, dbRenameStart);

    expect(dbRemoveStart).toBeGreaterThan(-1);
    expect(dbRenameStart).toBeGreaterThan(dbRemoveStart);
    expect(dbRemoveBlock).toContain('SJ_DEVICE_MUST_BE_REVOKED_FIRST');
    expect(dbRemoveBlock).toContain('v_revoked_at is null');
  });

  it('orders revoke before remove for the combined action', () => {
    const text = readFileSync(deviceAdminPath, 'utf8');
    const combinedStart = text.indexOf('async function revokeAndRemoveDevice');
    const renameStart = text.indexOf('async function renameDevice');
    const block = text.slice(combinedStart, renameStart);

    const revokeIndex = block.indexOf("'cs03_admin_revoke_device'");
    const removeIndex = block.indexOf("'cs03_admin_remove_device'");

    expect(revokeIndex).toBeGreaterThan(-1);
    expect(removeIndex).toBeGreaterThan(revokeIndex);
  });

  it('never hard-deletes trusted-device or user-device facts', () => {
    const text = readFileSync(deviceAdminPath, 'utf8').toLowerCase();

    expect(text).not.toContain('delete from public.trusted_devices');
    expect(text).not.toContain('delete from public.user_device_access');
    expect(text).not.toContain('.delete().from(');
  });

  it('validates a trimmed friendly name between 1 and 64 characters', () => {
    const text = readFileSync(deviceAdminPath, 'utf8');

    expect(text).toContain('value.trim()');
    expect(text).toContain('friendlyName.length === 0');
    expect(text).toContain('friendlyName.length > 64');
    expect(text).toContain('p_friendly_name: friendlyName');
  });

  it('keeps owner_list_devices projection coarse only', () => {
    const migration = readFileSync(migrationPath, 'utf8');
    const start = migration.indexOf(
      'create or replace function public.owner_list_devices',
    );
    const end = migration.indexOf(
      'revoke execute on function public.bootstrap_current_session',
    );
    const block = migration.slice(start, end);

    expect(start).toBeGreaterThan(-1);
    expect(end).toBeGreaterThan(start);

    for (const field of [
      "'profile_id'",
      "'device_id'",
      "'friendly_name'",
      "'device_kind'",
      "'platform_label'",
      "'last_seen_at'",
      "'revoked'",
      "'removed'",
      "'retired'",
    ]) {
      expect(block).toContain(field);
    }

    for (const forbidden of [
      'ip_address',
      'raw_user_agent',
      'user_agent',
      'internal_email',
      'password',
      'token',
    ]) {
      expect(block).not.toContain(forbidden);
    }
  });

  it('shows active-list device controls without raw IP or user-agent', () => {
    const text = readFileSync(ownerScreenPath, 'utf8');

    expect(text).toContain("rpc('owner_list_devices'");
    expect(text).toMatch(/functions\.invoke\(\s*'device-admin'/);
    expect(text).toContain('Perangkat Aktif');
    expect(text).toContain('Personal');
    expect(text).toContain('Bersama');
    expect(text).toContain('platform_label');
    expect(text).toContain('last_seen_at');
    expect(text).toContain('Cabut Akses');
    expect(text).toContain('Hapus dari Daftar');
    expect(text).toContain('Cabut & Hapus');
    expect(text).toContain('Ubah Nama');
    expect(text).toContain('showRemovedDevices || !device.removed');

    expect(text).not.toContain('ip_address');
    expect(text).not.toContain('raw_user_agent');
    expect(text).not.toContain('user_agent');
  });
});
