import {
  useCallback,
  useEffect,
  useMemo,
  useState,
  type FormEvent,
} from 'react';
import { useAuth } from '../auth/AuthProvider';
import type { PermissionCode, ProfileStatus } from '../auth/types';
import { supabase } from '../lib/supabase';

type PermissionEffect = 'ALLOW' | 'DENY' | 'INHERIT';

type UserPermissionOverride = {
  permission_code: string;
  effect: 'ALLOW' | 'DENY';
};

type OwnerUser = {
  profile_id: string;
  username: string;
  display_name: string;
  status: ProfileStatus;
  role_code: string;
  permission_overrides: UserPermissionOverride[];
};

type DeviceKind = 'PERSONAL' | 'SHARED';

type OwnerDevice = {
  profile_id: string;
  device_id: string;
  friendly_name: string;
  device_kind: DeviceKind;
  platform_label: string;
  last_seen_at: string | null;
  revoked: boolean;
  removed: boolean;
  retired: boolean;
};

type StatusFilter = 'ALL' | ProfileStatus;

const STATUS_LABELS: Record<ProfileStatus, string> = {
  ACTIVE: 'Aktif',
  LEAVE: 'Cuti',
  DISABLED: 'Dinonaktifkan',
};

const OPERATIONAL_PERMISSIONS: Array<{
  code: PermissionCode;
  label: string;
}> = [
  { code: 'EXPENSE_SHIFT_CREATE', label: 'Catat Pengeluaran Shift' },
  { code: 'INVENTORY_READ', label: 'Lihat Persediaan' },
  { code: 'PAYMENT_QRIS', label: 'Gunakan QRIS' },
  { code: 'PAYMENT_TRANSFER', label: 'Gunakan Transfer' },
  { code: 'CUSTOMER_DEBT_MANAGE', label: 'Kelola Hutang Pelanggan' },
  { code: 'INVENTORY_TRANSFER', label: 'Transfer Barang' },
  { code: 'PURCHASE_MANAGE', label: 'Kelola Pembelian' },
  { code: 'PRODUCTION_MANAGE', label: 'Kelola Produksi' },
  { code: 'CUSTOMER_MANAGE', label: 'Kelola Pelanggan' },
  { code: 'EMPLOYEE_MANAGE', label: 'Kelola Karyawan' },
  { code: 'CORRECTION_LIMITED', label: 'Koreksi Terbatas' },
  { code: 'REPORT_SALES_LIMITED', label: 'Laporan Penjualan Terbatas' },
  { code: 'REPORT_INVENTORY', label: 'Laporan Persediaan' },
  { code: 'REPORT_PURCHASE', label: 'Laporan Pembelian' },
  { code: 'REPORT_PRODUCTION', label: 'Laporan Produksi' },
  { code: 'SETTINGS_NONCRITICAL', label: 'Pengaturan Non-Kritis' },
];

function parseUsers(value: unknown): OwnerUser[] {
  if (!Array.isArray(value)) return [];

  return value.flatMap((item) => {
    if (typeof item !== 'object' || item === null || Array.isArray(item)) {
      return [];
    }

    const row = item as Record<string, unknown>;
    if (
      typeof row.profile_id !== 'string' ||
      typeof row.username !== 'string' ||
      typeof row.display_name !== 'string' ||
      typeof row.role_code !== 'string' ||
      !['ACTIVE', 'LEAVE', 'DISABLED'].includes(String(row.status))
    ) {
      return [];
    }

    const rawOverrides = Array.isArray(row.permission_overrides)
      ? row.permission_overrides
      : [];

    const permissionOverrides = rawOverrides.flatMap((override) => {
      if (
        typeof override !== 'object' ||
        override === null ||
        Array.isArray(override)
      ) {
        return [];
      }

      const entry = override as Record<string, unknown>;
      if (
        typeof entry.permission_code !== 'string' ||
        !['ALLOW', 'DENY'].includes(String(entry.effect))
      ) {
        return [];
      }

      return [
        {
          permission_code: entry.permission_code,
          effect: entry.effect as 'ALLOW' | 'DENY',
        },
      ];
    });

    return [
      {
        profile_id: row.profile_id,
        username: row.username,
        display_name: row.display_name,
        status: row.status as ProfileStatus,
        role_code: row.role_code,
        permission_overrides: permissionOverrides,
      },
    ];
  });
}

function parseDevices(value: unknown): OwnerDevice[] {
  if (!Array.isArray(value)) return [];

  return value.flatMap((item) => {
    if (typeof item !== 'object' || item === null || Array.isArray(item)) {
      return [];
    }

    const row = item as Record<string, unknown>;
    if (
      typeof row.profile_id !== 'string' ||
      typeof row.device_id !== 'string' ||
      typeof row.friendly_name !== 'string' ||
      !['PERSONAL', 'SHARED'].includes(String(row.device_kind)) ||
      typeof row.platform_label !== 'string' ||
      !(row.last_seen_at === null || typeof row.last_seen_at === 'string') ||
      typeof row.revoked !== 'boolean' ||
      typeof row.removed !== 'boolean' ||
      typeof row.retired !== 'boolean'
    ) {
      return [];
    }

    return [
      {
        profile_id: row.profile_id,
        device_id: row.device_id,
        friendly_name: row.friendly_name,
        device_kind: row.device_kind as DeviceKind,
        platform_label: row.platform_label,
        last_seen_at: row.last_seen_at,
        revoked: row.revoked,
        removed: row.removed,
        retired: row.retired,
      },
    ];
  });
}

function formatLastSeen(value: string | null): string {
  if (!value) return 'Belum tercatat';

  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return 'Tidak diketahui';

  return date.toLocaleString('id-ID');
}

export function OwnerUsersScreen() {
  const { refreshAuthority } = useAuth();
  const [users, setUsers] = useState<OwnerUser[]>([]);
  const [filter, setFilter] = useState<StatusFilter>('ALL');
  const [selectedProfileId, setSelectedProfileId] = useState('');
  const [message, setMessage] = useState('');
  const [busy, setBusy] = useState(false);

  const [devices, setDevices] = useState<OwnerDevice[]>([]);
  const [showRemovedDevices, setShowRemovedDevices] = useState(false);

  const [newUsername, setNewUsername] = useState('');
  const [newDisplayName, setNewDisplayName] = useState('');
  const [newPassword, setNewPassword] = useState('');

  const loadUsers = useCallback(async () => {
    const { data, error } = await supabase.rpc('owner_list_users');
    if (error) {
      setMessage('Daftar pengguna tidak dapat dimuat.');
      return;
    }

    const next = parseUsers(data);
    setUsers(next);

    if (
      selectedProfileId &&
      !next.some((user) => user.profile_id === selectedProfileId)
    ) {
      setSelectedProfileId('');
    }
  }, [selectedProfileId]);

  const loadDevices = useCallback(async (profileId: string) => {
    const { data, error } = await supabase.rpc('owner_list_devices', {
      p_profile_id: profileId,
    });

    if (error) {
      setMessage('Daftar perangkat tidak dapat dimuat.');
      return;
    }

    setDevices(parseDevices(data));
  }, []);

  useEffect(() => {
    void loadUsers();
  }, [loadUsers]);

  useEffect(() => {
    if (!selectedProfileId) {
      setDevices([]);
      return;
    }

    void loadDevices(selectedProfileId);
  }, [loadDevices, selectedProfileId]);

  const filteredUsers = useMemo(
    () =>
      filter === 'ALL' ? users : users.filter((user) => user.status === filter),
    [filter, users],
  );

  const selected =
    users.find((user) => user.profile_id === selectedProfileId) ?? null;

  const visibleDevices = devices.filter(
    (device) => showRemovedDevices || !device.removed,
  );

  async function invokeAdmin(body: Record<string, unknown>) {
    setBusy(true);
    setMessage('');

    try {
      const { data, error } = await supabase.functions.invoke(
        'identity-admin',
        {
          body,
        },
      );

      if (error) {
        throw new Error('SJ_IDENTITY_ADMIN_FAILED');
      }

      const envelope = data as {
        ok?: boolean;
        data?: unknown;
        error?: { message?: string };
      } | null;

      if (!envelope?.ok) {
        throw new Error(
          envelope?.error?.message || 'Perubahan pengguna gagal.',
        );
      }

      await refreshAuthority();
      await loadUsers();
      setMessage('Perubahan berhasil disimpan.');
      return envelope.data;
    } catch (error) {
      setMessage(
        error instanceof Error ? error.message : 'Perubahan pengguna gagal.',
      );
      return null;
    } finally {
      setBusy(false);
    }
  }

  async function invokeDeviceAdmin(body: Record<string, unknown>) {
    setBusy(true);
    setMessage('');

    try {
      const { data, error } = await supabase.functions.invoke('device-admin', {
        body,
      });

      if (error) {
        throw new Error('SJ_DEVICE_ADMIN_FAILED');
      }

      const envelope = data as {
        ok?: boolean;
        data?: unknown;
        error?: { message?: string };
      } | null;

      if (!envelope?.ok) {
        throw new Error(
          envelope?.error?.message || 'Perubahan perangkat gagal.',
        );
      }

      if (selectedProfileId) {
        await loadDevices(selectedProfileId);
      }

      setMessage('Perubahan perangkat berhasil disimpan.');
      return envelope.data;
    } catch (error) {
      setMessage(
        error instanceof Error ? error.message : 'Perubahan perangkat gagal.',
      );
      return null;
    } finally {
      setBusy(false);
    }
  }

  async function createStaff(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();

    const result = await invokeAdmin({
      action: 'create_staff',
      username: newUsername,
      display_name: newDisplayName,
      password: newPassword,
      role_code: 'KASIR',
    });

    setNewPassword('');

    if (result) {
      setNewUsername('');
      setNewDisplayName('');
    }
  }

  async function resetPassword(user: OwnerUser) {
    const password = window.prompt(
      `Password baru untuk ${user.display_name} (8–72 karakter):`,
    );
    if (!password) return;

    await invokeAdmin({
      action: 'reset_password',
      profile_id: user.profile_id,
      password,
    });
  }

  async function setStatus(user: OwnerUser, status: ProfileStatus) {
    await invokeAdmin({
      action: 'set_status',
      profile_id: user.profile_id,
      status,
    });
  }

  async function setPermission(
    user: OwnerUser,
    permissionCode: PermissionCode,
    effect: PermissionEffect,
  ) {
    await invokeAdmin({
      action: 'set_permission',
      profile_id: user.profile_id,
      permission_code: permissionCode,
      effect,
    });
  }

  async function renameDevice(device: OwnerDevice) {
    const friendlyName = window.prompt(
      'Nama perangkat baru (1–64 karakter):',
      device.friendly_name,
    );
    if (friendlyName === null) return;

    await invokeDeviceAdmin({
      action: 'rename_device',
      device_id: device.device_id,
      friendly_name: friendlyName,
    });
  }

  async function revokeDevice(user: OwnerUser, device: OwnerDevice) {
    if (
      !window.confirm(
        `Cabut akses ${device.friendly_name} untuk ${user.display_name}?`,
      )
    ) {
      return;
    }

    await invokeDeviceAdmin({
      action: 'revoke_device',
      profile_id: user.profile_id,
      device_id: device.device_id,
    });
  }

  async function removeDevice(user: OwnerUser, device: OwnerDevice) {
    if (!device.revoked) {
      setMessage('Cabut akses perangkat sebelum menghapus dari daftar.');
      return;
    }

    if (
      !window.confirm(
        `Hapus ${device.friendly_name} dari daftar perangkat aktif?`,
      )
    ) {
      return;
    }

    await invokeDeviceAdmin({
      action: 'remove_device',
      profile_id: user.profile_id,
      device_id: device.device_id,
    });
  }

  async function revokeAndRemoveDevice(user: OwnerUser, device: OwnerDevice) {
    if (
      !window.confirm(
        `Cabut akses dan hapus ${device.friendly_name} dari daftar?`,
      )
    ) {
      return;
    }

    await invokeDeviceAdmin({
      action: 'revoke_and_remove',
      profile_id: user.profile_id,
      device_id: device.device_id,
    });
  }

  function overrideEffect(
    user: OwnerUser,
    permissionCode: PermissionCode,
  ): PermissionEffect {
    return (
      user.permission_overrides.find(
        (entry) => entry.permission_code === permissionCode,
      )?.effect ?? 'INHERIT'
    );
  }

  return (
    <main className="shell">
      <header className="topbar">
        <div>
          <p className="eyebrow">OWNER</p>
          <h1>Pengguna</h1>
          <p className="muted">
            Kelola staf, status, password, dan izin operasional.
          </p>
        </div>
      </header>

      {message && (
        <p className="form-error" role="status">
          {message}
        </p>
      )}

      <section className="identity-card">
        <h2>Tambah Staf</h2>
        <form className="stack" onSubmit={createStaff}>
          <label>
            <span className="field-label">Username</span>
            <input
              value={newUsername}
              onChange={(event) => setNewUsername(event.target.value)}
              autoComplete="off"
              required
            />
          </label>
          <label>
            <span className="field-label">Nama Tampilan</span>
            <input
              value={newDisplayName}
              onChange={(event) => setNewDisplayName(event.target.value)}
              required
            />
          </label>
          <label>
            <span className="field-label">Password Awal</span>
            <input
              type="password"
              value={newPassword}
              onChange={(event) => setNewPassword(event.target.value)}
              autoComplete="new-password"
              minLength={8}
              maxLength={72}
              required
            />
          </label>
          <button className="primary-button" disabled={busy} type="submit">
            Tambah Staf
          </button>
        </form>
      </section>

      <section>
        <h2>Daftar Pengguna</h2>
        <div className="chip-row" aria-label="Filter status">
          {(
            [
              ['ALL', 'Semua'],
              ['ACTIVE', 'Aktif'],
              ['LEAVE', 'Cuti'],
              ['DISABLED', 'Dinonaktifkan'],
            ] as const
          ).map(([value, label]) => (
            <button
              className="chip"
              type="button"
              key={value}
              aria-pressed={filter === value}
              onClick={() => setFilter(value)}
            >
              {label}
            </button>
          ))}
        </div>

        <div className="stack">
          {filteredUsers.map((user) => (
            <article className="identity-card" key={user.profile_id}>
              <button
                type="button"
                className="chip"
                onClick={() => setSelectedProfileId(user.profile_id)}
              >
                {user.display_name} · @{user.username}
              </button>
              <p className="muted">
                {user.role_code} · {STATUS_LABELS[user.status]}
              </p>

              {user.role_code !== 'OWNER' && (
                <div className="button-row">
                  <button
                    className="secondary-button"
                    type="button"
                    disabled={busy}
                    onClick={() => void resetPassword(user)}
                  >
                    Reset Password
                  </button>
                  <button
                    className="secondary-button"
                    type="button"
                    disabled={busy}
                    onClick={() => void setStatus(user, 'ACTIVE')}
                  >
                    Aktif
                  </button>
                  <button
                    className="secondary-button"
                    type="button"
                    disabled={busy}
                    onClick={() => void setStatus(user, 'LEAVE')}
                  >
                    Cuti
                  </button>
                  <button
                    className="secondary-button"
                    type="button"
                    disabled={busy}
                    onClick={() => void setStatus(user, 'DISABLED')}
                  >
                    Dinonaktifkan
                  </button>
                </div>
              )}
            </article>
          ))}
        </div>
      </section>

      {selected && selected.role_code !== 'OWNER' && (
        <section className="identity-card">
          <h2>Izin Operasional · {selected.display_name}</h2>
          <div className="stack">
            {OPERATIONAL_PERMISSIONS.map(({ code, label }) => (
              <label key={code}>
                <span className="field-label">{label}</span>
                <select
                  value={overrideEffect(selected, code)}
                  disabled={busy}
                  onChange={(event) =>
                    void setPermission(
                      selected,
                      code,
                      event.target.value as PermissionEffect,
                    )
                  }
                >
                  <option value="INHERIT">Ikuti Role</option>
                  <option value="ALLOW">Izinkan</option>
                  <option value="DENY">Tolak</option>
                </select>
              </label>
            ))}
          </div>
        </section>
      )}

      {selected && (
        <section className="identity-card">
          <div className="topbar">
            <div>
              <p className="eyebrow">PERANGKAT</p>
              <h2>Perangkat Aktif · {selected.display_name}</h2>
            </div>
            <label className="radio-row">
              <input
                type="checkbox"
                checked={showRemovedDevices}
                onChange={(event) =>
                  setShowRemovedDevices(event.target.checked)
                }
              />
              Tampilkan yang dihapus
            </label>
          </div>

          <div className="stack">
            {visibleDevices.length === 0 && (
              <p className="muted">Belum ada perangkat tercatat.</p>
            )}

            {visibleDevices.map((device) => (
              <article className="identity-card" key={device.device_id}>
                <strong>{device.friendly_name}</strong>
                <p className="muted">
                  {device.device_kind === 'SHARED' ? 'Bersama' : 'Personal'}
                  {' · '}
                  {device.platform_label}
                </p>
                <p className="muted">
                  Terakhir terlihat: {formatLastSeen(device.last_seen_at)}
                </p>
                <p>
                  Status:{' '}
                  <strong>
                    {device.removed
                      ? 'Dihapus dari daftar'
                      : device.revoked || device.retired
                        ? 'Dicabut'
                        : 'Aktif'}
                  </strong>
                </p>

                {!device.removed && (
                  <div className="button-row">
                    <button
                      className="secondary-button"
                      type="button"
                      disabled={busy}
                      onClick={() => void renameDevice(device)}
                    >
                      Ubah Nama
                    </button>
                    <button
                      className="secondary-button"
                      type="button"
                      disabled={busy || device.revoked || device.retired}
                      onClick={() => void revokeDevice(selected, device)}
                    >
                      Cabut Akses
                    </button>
                    <button
                      className="secondary-button"
                      type="button"
                      disabled={busy || !device.revoked}
                      onClick={() => void removeDevice(selected, device)}
                    >
                      Hapus dari Daftar
                    </button>
                    <button
                      className="secondary-button"
                      type="button"
                      disabled={busy || device.revoked || device.retired}
                      onClick={() =>
                        void revokeAndRemoveDevice(selected, device)
                      }
                    >
                      Cabut & Hapus
                    </button>
                  </div>
                )}
              </article>
            ))}
          </div>
        </section>
      )}
    </main>
  );
}
