import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ui/ui.dart';

import '../../app/warga_state.dart';
import '../report/outbox_status_sheet.dart';

/// Redesigned Settings & Emergency Preferences for Warga (FR-BLE-11, FR-BCN-05).
///
/// Provides:
/// - Emergency Battery Preservation Mode (Duty-cycle 4s scan / 90s sleep)
/// - WE-IRED Beacon Assembly Point Auto Check-in Toggle
/// - System Hardware & Communication Permissions Status
/// - Dedicated Jury Simulation Deck (Toggle Siaga, Toggle Latihan vs Nyata)
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(wargaProvider);
    final notifier = ref.read(wargaProvider.notifier);

    return Scaffold(
      backgroundColor: AppTheme.bgCanvas,
      appBar: AppBar(
        title: const Text(
          'Pengaturan & Simulasi',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        centerTitle: false,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          children: [
            // ==========================================
            // EFISIENSI DAYA & BLUETOOTH (FR-BLE-11, F-24)
            // ==========================================
            const OperationalSectionHeader(
              title: 'Pengelolaan Daya Baterai Ponsel',
              subtitle: 'Optimalisasi perangkat saat aliran listrik PLN padam total',
            ),
            const SizedBox(height: 8),
            Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.borderSubtle),
                ),
                child: SwitchListTile(
                  value: state.batterySavingMode,
                  activeThumbColor: AppTheme.primaryBlue,
                  title: const Text(
                    'Mode Hemat Baterai Darurat',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.slate900),
                  ),
                  subtitle: const Text(
                    'Memperpanjang jeda pemindaian Bluetooth LE (siklus hemat 4s pindai / 90s istirahat) untuk memperpanjang daya baterai ponsel hingga 72 jam.',
                    style: TextStyle(fontSize: 11, color: AppTheme.slate600, height: 1.35),
                  ),
                  onChanged: (val) => notifier.toggleBatteryMode(val),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // ==========================================
            // DETEKSI WE-IRED BEACON (FR-BCN-05)
            // ==========================================
            const OperationalSectionHeader(
              title: 'Deteksi Beacon Titik Kumpul',
              subtitle: 'Check-in otomatis saat tiba di lokasi evakuasi Balai RW',
            ),
            const SizedBox(height: 8),
            Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.borderSubtle),
                ),
                child: SwitchListTile(
                  value: state.autoCheckinBeacon,
                  activeThumbColor: AppTheme.statusAman,
                  title: const Text(
                    'Check-in Otomatis di Titik Kumpul',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.slate900),
                  ),
                  subtitle: const Text(
                    'Saat sinyal Bluetooth perangkat WE-IRED Beacon di Balai RW terdeteksi stabil selama >= 10 detik, sistem otomatis mencatat status Anda sebagai "Di Titik Kumpul".',
                    style: TextStyle(fontSize: 11, color: AppTheme.slate600, height: 1.35),
                  ),
                  onChanged: (val) => notifier.toggleAutoCheckin(val),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // ==========================================
            // STATUS IZIN PERANGKAT
            // ==========================================
            const OperationalSectionHeader(
              title: 'Status Izin Perangkat',
              subtitle: 'Izin penting untuk menjaga alur komunikasi darurat',
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.borderSubtle),
              ),
              child: Column(
                children: const [
                  _PermissionStatusRow(
                    icon: Icons.bluetooth_connected,
                    name: 'Bluetooth & Perangkat Sekitar (Relay BLE)',
                    status: 'Aktif & Siap',
                    isOk: true,
                  ),
                  Divider(height: 16),
                  _PermissionStatusRow(
                    icon: Icons.location_on,
                    name: 'Lokasi & Titik Kumpul (GPS)',
                    status: 'Aktif & Siap',
                    isOk: true,
                  ),
                  Divider(height: 16),
                  _PermissionStatusRow(
                    icon: Icons.notifications_active,
                    name: 'Pemberitahuan Sirine Darurat (Notifikasi)',
                    status: 'Aktif & Siap',
                    isOk: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ==========================================
            // KONTROL SIMULASI & DEMONSTRASI JURI
            // ==========================================
            const OperationalSectionHeader(
              title: 'Kontrol Pengujian & Simulasi Juri',
              subtitle: 'Alat pengujian langsung untuk mengubah kondisi lingkungan',
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.primaryBlue, width: 1.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Status Mode Siaga Bencana',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.slate900),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              state.isSiaga ? 'KONDISI: SIAGA AKTIF' : 'KONDISI: NORMAL / AMAN',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: state.isSiaga ? AppTheme.statusKritis : AppTheme.statusAman,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: () => notifier.toggleSiagaMode(),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: state.isSiaga ? AppTheme.statusKritis : AppTheme.primaryBlue,
                          side: BorderSide(
                            color: state.isSiaga ? AppTheme.statusKritisBorder : AppTheme.primaryBlue,
                          ),
                        ),
                        child: Text(state.isSiaga ? 'Matikan Siaga' : 'Aktifkan Siaga'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Tipe Bencana yang Aktif',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.slate900),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              state.isDrill ? '[MODE LATIHAN / DRILL RT]' : '[DARURAT NYATA AKTIF]',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                color: state.isDrill ? const Color(0xFFD97706) : AppTheme.statusKritis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: state.isSiaga ? () => notifier.toggleDrillMode() : null,
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppTheme.borderStrong),
                        ),
                        child: const Text('Ganti Mode'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Divider(height: 1),
                  const SizedBox(height: 12),

                  // SIMULASI MODE KONEKSI JARINGAN (FR-SYNC-01)
                  const Text(
                    'Simulasi Konektivitas Jaringan Perangkat',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.slate900),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Uji bagaimana laporan dikirim: langsung cloud/posko, via relay relawan, atau antrean outbox luring.',
                    style: TextStyle(fontSize: 11, color: AppTheme.slate500),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('Online (Posko/Cloud)', style: TextStyle(fontSize: 11)),
                        selected: state.connectionMode == ConnectionMode.online,
                        onSelected: (_) => notifier.setConnectionMode(ConnectionMode.online),
                        selectedColor: const Color(0xFFDCFCE7),
                      ),
                      ChoiceChip(
                        label: const Text('Mesh Relay (BLE)', style: TextStyle(fontSize: 11)),
                        selected: state.connectionMode == ConnectionMode.meshRelay,
                        onSelected: (_) => notifier.setConnectionMode(ConnectionMode.meshRelay),
                        selectedColor: const Color(0xFFEFF6FF),
                      ),
                      ChoiceChip(
                        label: const Text('Luring Total (Offline)', style: TextStyle(fontSize: 11)),
                        selected: state.connectionMode == ConnectionMode.offline,
                        onSelected: (_) => notifier.setConnectionMode(ConnectionMode.offline),
                        selectedColor: const Color(0xFFFEF3C7),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Divider(height: 1),
                  const SizedBox(height: 12),

                  // SIMULASI JARAK BEACON TITIK KUMPUL (FR-BCN-05)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Simulasi Kehadiran di Dekat Beacon',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.slate900),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              state.beaconInRange
                                  ? 'BEACON TERDETEKSI (Balai RW, -68 dBm)'
                                  : 'DI LUAR JANGKAUAN BEACON',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: state.beaconInRange ? AppTheme.primaryBlue : AppTheme.slate500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: () => notifier.toggleBeaconInRange(!state.beaconInRange),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppTheme.borderStrong),
                        ),
                        child: Text(state.beaconInRange ? 'Jauhkan Beacon' : 'Dekatkan Beacon'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Divider(height: 1),
                  const SizedBox(height: 12),

                  // LIHAT STATUS OUTBOX
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.outbox, size: 16),
                      label: Text('Buka Antrean Outbox (${state.outbox.length} item)'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primaryBlue,
                        side: const BorderSide(color: AppTheme.primaryBlue),
                      ),
                      onPressed: () => OutboxStatusSheet.show(context),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // ==========================================
            // INFO APLIKASI & LOGOUT
            // ==========================================
            Center(
              child: Column(
                children: [
                  const Text(
                    'WE-IRED Warga • Versi 0.1.0',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.slate600),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'STACK 2026 by GDGoC ITB • Kasus 2: Stronger Communities',
                    style: TextStyle(fontSize: 10, color: AppTheme.slate400),
                  ),
                  const SizedBox(height: 16),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.statusKritis,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                    icon: const Icon(Icons.logout, size: 16),
                    label: const Text('Keluar dari Akun Rumah Tangga', style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: () {
                      notifier.logout();
                      context.go('/onboarding');
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class _PermissionStatusRow extends StatelessWidget {
  final IconData icon;
  final String name;
  final String status;
  final bool isOk;

  const _PermissionStatusRow({
    required this.icon,
    required this.name,
    required this.status,
    required this.isOk,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: isOk ? AppTheme.statusAman : AppTheme.slate400),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            name,
            style: const TextStyle(fontSize: 12, color: AppTheme.slate800),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFFDCFCE7),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            status,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.statusAman),
          ),
        ),
      ],
    );
  }
}
