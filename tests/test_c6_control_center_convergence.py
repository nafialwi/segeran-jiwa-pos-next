from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
APP = ROOT / "src/App.tsx"
MENU = ROOT / "src/screens/MenuScreen.tsx"
CONTROL = ROOT / "src/screens/ControlCenterScreen.tsx"
HEALTH = ROOT / "src/screens/SystemHealthScreen.tsx"
BACKUP = ROOT / "src/screens/BackupRestoreScreen.tsx"
OFFLINE = ROOT / "src/screens/OfflineSyncScreen.tsx"
DIAGNOSTICS = ROOT / "src/screens/DiagnosticsScreen.tsx"
APPEARANCE = ROOT / "src/screens/AppearanceSettingsScreen.tsx"
ATTENTION = ROOT / "src/screens/AttentionScreen.tsx"
CONTROL_API = ROOT / "src/control/control-center-api.ts"
PREFS = ROOT / "src/control/preferences.ts"
EVIDENCE = ROOT / "src/control/backup-evidence.ts"
USERS = ROOT / "src/screens/OwnerUsersScreen.tsx"
CSS = ROOT / "src/app.css"


class C6ControlCenterTests(unittest.TestCase):
    def test_control_center_routes_are_permission_bounded(self):
        src = APP.read_text(encoding="utf-8")
        for route in (
            '/pengaturan',
            '/pengaturan/tampilan',
            '/pengaturan/kesehatan',
            '/pengaturan/backup',
            '/pengaturan/offline-sync',
            '/pengaturan/diagnostik',
        ):
            self.assertIn(f'path="{route}"', src)
        self.assertIn("SETTINGS_NONCRITICAL", src)

    def test_menu_surfaces_settings_control_center(self):
        src = MENU.read_text(encoding="utf-8")
        self.assertIn("Pengaturan", src)
        self.assertIn("Pusat kontrol sistem dan perangkat", src)
        self.assertIn("to: '/pengaturan'", src)

    def test_control_center_covers_board04_authorities(self):
        src = CONTROL.read_text(encoding="utf-8")
        for token in (
            "Pusat Kontrol",
            "Tampilan & Dashboard",
            "Keuangan",
            "Pengguna & Izin",
            "Perangkat Aktif",
            "Perhatian",
            "Backup & Restore",
            "Kesehatan Sistem",
            "Offline & Sync",
            "Diagnostik",
        ):
            self.assertIn(token, src)
        self.assertIn("canAccessOwnerArea", src)

    def test_backend_health_is_a_live_authority_probe_not_navigator_online(self):
        api = CONTROL_API.read_text(encoding="utf-8")
        self.assertIn("get_my_authority", api)
        self.assertIn("BACKEND_AUTHORITY", api)
        self.assertIn("checkedAt", api)
        self.assertIn("latencyMs", api)
        self.assertNotIn("navigator.onLine", api)

        screen = HEALTH.read_text(encoding="utf-8")
        self.assertIn("Backend Authority", screen)
        self.assertIn("Koneksi Perangkat", screen)
        self.assertIn("bukan bukti kesehatan backend", screen)

    def test_backup_is_checkpoint_evidence_not_fake_realtime_green(self):
        evidence = EVIDENCE.read_text(encoding="utf-8")
        screen = BACKUP.read_text(encoding="utf-8")
        self.assertIn("VERIFIED_CHECKPOINT", evidence)
        self.assertIn("2026-09-21", evidence)
        self.assertIn("isolated PostgreSQL 18.6", evidence)
        self.assertIn("Bukti terakhir", screen)
        self.assertIn("bukan status backup realtime", screen)
        self.assertIn("Restore Otomatis Tidak Tersedia", screen)
        self.assertNotIn("BACKUP_HEALTHY_NOW", evidence + screen)

    def test_attention_is_actionable_and_evidence_bounded(self):
        src = ATTENTION.read_text(encoding="utf-8")
        self.assertIn("probeBackendAuthority", src)
        self.assertIn("/pengaturan/kesehatan", src)
        self.assertIn("/pengaturan/backup", src)
        self.assertIn("Tidak berarti seluruh sistem sehat", src)
        self.assertIn("Coba Lagi", src)

    def test_offline_sync_explicitly_has_no_mutation_queue(self):
        src = OFFLINE.read_text(encoding="utf-8")
        self.assertIn("Tidak ada antrean mutasi offline", src)
        self.assertIn("Operasi server tetap online-only", src)
        self.assertIn("Koneksi Perangkat", src)
        self.assertIn("bukan status", src)
        self.assertIn("backend", src)

    def test_diagnostics_exposes_safe_runtime_evidence(self):
        src = DIAGNOSTICS.read_text(encoding="utf-8")
        self.assertIn("Backend probe", src)
        self.assertIn("Device ID", src)
        self.assertIn("Role", src)
        self.assertIn("Mode aplikasi", src)
        self.assertIn("Tidak menampilkan token", src)

    def test_preferences_are_noncritical_device_local_and_applied(self):
        prefs = PREFS.read_text(encoding="utf-8")
        screen = APPEARANCE.read_text(encoding="utf-8")
        css = CSS.read_text(encoding="utf-8")
        self.assertIn("sjpos.control.preferences.v1", prefs)
        self.assertIn("data-sj-density", prefs)
        self.assertIn("data-sj-font-scale", prefs)
        self.assertIn("Preferensi perangkat ini", screen)
        self.assertIn("Nyaman", screen)
        self.assertIn("Ringkas", screen)
        self.assertIn("Teks Besar", screen)
        self.assertIn("[data-sj-density='compact']", css)
        self.assertIn("[data-sj-font-scale='large']", css)

    def test_existing_owner_devices_and_permissions_are_addressable(self):
        src = USERS.read_text(encoding="utf-8")
        self.assertIn('id="permissions"', src)
        self.assertIn('id="devices"', src)
        self.assertIn("owner_list_devices", src)

    def test_no_c6_database_migration(self):
        migrations = list((ROOT / "supabase/migrations").glob("*c6_control*"))
        self.assertEqual([], migrations)


if __name__ == "__main__":
    unittest.main()
