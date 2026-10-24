import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core/core.dart';
import 'package:ui/ui.dart';

import '../../app/warga_state.dart';

/// Modal bottom sheet for Beacon-assisted assembly point check-in (FR-BCN-05..06, AC-06)
class BeaconCheckinSheet extends ConsumerWidget {
  const BeaconCheckinSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const BeaconCheckinSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(wargaProvider);
    final notifier = ref.read(wargaProvider.notifier);
    final inRange = state.beaconInRange;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag Handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.slate300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Title Row
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.statusTitikKumpul.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.sensors, color: AppTheme.statusTitikKumpul, size: 24),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Deteksi Beacon Titik Kumpul',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.slate900),
                        ),
                        Text(
                          'Sensor BLE Titik Kumpul RT/RW (FR-BCN-05)',
                          style: TextStyle(fontSize: 12, color: AppTheme.slate500),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(height: 24),

              // Beacon Sensor Card
              if (inRange) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: const BoxDecoration(
                              color: AppTheme.statusAman,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'SINYAL BEACON TERDETEKSI',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1E40AF)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${state.detectedBeaconRssi} dBm (Kuat)',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.statusAman),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        state.detectedBeaconName ?? 'Balai RW 02 (Titik Kumpul Utama)',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.slate900),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'ID Perangkat: ${state.detectedBeaconId ?? "BCN-RW02-01"} • Jarak estimasi ~6-8 meter',
                        style: const TextStyle(fontSize: 12, color: AppTheme.slate600),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFDBEAFE)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.verified_outlined, size: 16, color: AppTheme.statusAman),
                            SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Sinyal terverifikasi stabil >= 10 detik. Memenuhi bukti fisik kehadiran titik kumpul.',
                                style: TextStyle(fontSize: 11, color: AppTheme.slate700),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Check-in Button >= 64dp
                SizedBox(
                  width: double.infinity,
                  height: 64,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.statusTitikKumpul,
                      foregroundColor: Colors.white,
                      elevation: 2,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () {
                      notifier.triggerBeaconCheckin();
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Berhasil check-in di Balai RW 02 via WE-IRED Beacon.'),
                          backgroundColor: AppTheme.statusAman,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    child: const Row(
                      children: [
                        Icon(Icons.check_circle, size: 24),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'KONFIRMASI CHECK-IN',
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                'Bukti kehadiran beacon BCN-RW02-01',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.normal, color: Colors.white70),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ] else ...[
                // Out of range card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.wifi_off, size: 18, color: Color(0xFFD97706)),
                          SizedBox(width: 8),
                          Text(
                            'BEACON BELUM TERDETEKSI',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF92400E)),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Ponsel belum mendeteksi sinyal Bluetooth dari tiang Beacon Balai RW 02. Pastikan Bluetooth aktif dan Anda berada dalam radius 15 meter dari titik kumpul.',
                        style: TextStyle(fontSize: 12, color: AppTheme.slate700, height: 1.4),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Manual Check-in option
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.statusTitikKumpul,
                      side: const BorderSide(color: AppTheme.statusTitikKumpul, width: 1.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () {
                      notifier.submitQuickReport(ReportStatus.titikKumpul);
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Laporan tiba di Titik Kumpul (manual) telah dicatat.'),
                          backgroundColor: AppTheme.statusTitikKumpul,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.edit_location_alt, size: 18),
                        SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'Lapor Tiba Manual (Tanpa Sensor Beacon)',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 16),

              // Auto-checkin switch
              Material(
                color: AppTheme.slate50,
                borderRadius: BorderRadius.circular(8),
                child: SwitchListTile(
                  dense: true,
                  value: state.autoCheckinBeacon,
                  title: const Text(
                    'Check-in Otomatis saat Mendekat (FR-BCN-05)',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.slate900),
                  ),
                  subtitle: const Text(
                    'Otomatis mencatat status saat sinyal stabil >= 10 detik tanpa konfirmasi manual.',
                    style: TextStyle(fontSize: 10, color: AppTheme.slate500),
                  ),
                  onChanged: (val) => notifier.toggleAutoCheckin(val),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
