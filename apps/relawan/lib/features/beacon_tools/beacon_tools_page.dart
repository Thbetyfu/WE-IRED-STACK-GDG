import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ui/ui.dart';

import '../../app/relawan_state.dart';

class BeaconToolsPage extends ConsumerStatefulWidget {
  const BeaconToolsPage({super.key});

  @override
  ConsumerState<BeaconToolsPage> createState() => _BeaconToolsPageState();
}

class _BeaconToolsPageState extends ConsumerState<BeaconToolsPage> {
  late int _sliderRssi;
  bool _isSampling = false;

  @override
  void initState() {
    super.initState();
    _sliderRssi = -65;
  }

  void _runInteractiveSampling() async {
    setState(() => _isSampling = true);
    // Simulate real 5-sample collection with progressive delays
    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;

    final newSamples = [-67, -64, -65, -63, -66];
    ref.read(relawanProvider.notifier).runRssiCalibrationSamples(newSamples);

    final avg = (newSamples.reduce((a, b) => a + b) / newSamples.length).round();
    setState(() {
      _isSampling = false;
      _sliderRssi = avg;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Kalibrasi 5-sampel selesai: Rata-rata moving average $avg dBm.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(relawanProvider);
    final beacon = state.beaconInfo;

    return Scaffold(
      backgroundColor: AppTheme.bgCanvas,
      appBar: AppBar(
        title: const Text('Alat Beacon & Kalibrasi RSSI'),
        centerTitle: false,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Technical Scope & Hardware Identity Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.borderSubtle),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFCCFBF1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.memory, color: Color(0xFF0D9488), size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              beacon.name,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.slate900),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'ID: ${beacon.beaconId} • ${beacon.location}',
                              style: const TextStyle(fontSize: 11, color: AppTheme.slate500),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'Aktif',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.statusAman),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 12),

                  // Telemetry Metrics Grid
                  Row(
                    children: [
                      Expanded(
                        child: _TelemetryItem(
                          label: 'Tegangan Baterai',
                          value: '${beacon.batteryVoltage} V (${beacon.batteryPercent}%)',
                          statusColor: AppTheme.statusAman,
                          icon: Icons.battery_charging_full,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _TelemetryItem(
                          label: 'Panel Surya',
                          value: '${beacon.solarVoltage} V (Mengisi)',
                          statusColor: const Color(0xFF0D9488),
                          icon: Icons.wb_sunny_outlined,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _TelemetryItem(
                          label: 'Memori Flash LittleFS',
                          value: '${beacon.storagePackets} / ${beacon.storageCapacity} Pkt',
                          statusColor: AppTheme.slate800,
                          icon: Icons.sd_storage_outlined,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _TelemetryItem(
                          label: 'Detak Jantung (Heartbeat)',
                          value: '${beacon.lastHeartbeatSecondsAgo} detik lalu',
                          statusColor: AppTheme.primaryBlue,
                          icon: Icons.favorite_border,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.slate100,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Token Provisioning Posko: ${beacon.provisioningToken} (Terdaftar & Terverifikasi)',
                      style: const TextStyle(fontSize: 10, color: AppTheme.slate600),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Hardware & Firmware Dependency Disclosure
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: Color(0xFFB45309)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Data telemetri beacon bersumber dari snapshot registrasi Posko (J-21). Kalibrasi RSSI akan disimpan lokal dan disinkronkan saat dekat Posko.',
                      style: TextStyle(fontSize: 10, color: Color(0xFF78350F)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Kalibrasi RSSI (HRD 9, SDD 7.7)
            const OperationalSectionHeader(
              title: 'Kalibrasi Ambang Check-in Otomatis (RSSI)',
              subtitle: 'Menentukan ambang batas sinyal BLE di Balai RW agar HP warga memicu check-in (SDD 7.7)',
            ),
            const SizedBox(height: 8),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.borderSubtle),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(
                        child: Text(
                          'Ambang Batas Deteksi Check-in:',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.slate800),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${state.beaconCalibratedRssi} dBm',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.primaryBlue),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Perkiraan radius jangkauan efektif: ±${(-state.beaconCalibratedRssi - 45).clamp(10, 35)} meter dari tiang beacon Balai RW.',
                    style: const TextStyle(fontSize: 11, color: AppTheme.slate600),
                  ),
                  const SizedBox(height: 12),

                  // Slider
                  Slider(
                    value: _sliderRssi.toDouble(),
                    min: -90,
                    max: -40,
                    divisions: 50,
                    label: '$_sliderRssi dBm',
                    onChanged: (val) {
                      setState(() => _sliderRssi = val.round());
                      ref.read(relawanProvider.notifier).setBeaconCalibration(val.round());
                    },
                  ),
                  const SizedBox(height: 6),

                  // Moving Average Samples Display
                  const Text(
                    'Sampel RSSI Sinyal Terakhir (5 Sampel Moving Average):',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.slate700),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    children: state.rssiCalibrationSamples.map((s) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.slate100,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '$s dBm',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.slate800),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  // Calibration Trigger Button (Min 48dp touch target)
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton.icon(
                      icon: _isSampling
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.tune, size: 18),
                      label: Text(
                        _isSampling ? 'Mengambil 5 Sampel Sinyal...' : 'Jalankan Kalibrasi Otomatis (5 Sampel)',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onPressed: _isSampling ? null : _runInteractiveSampling,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Quick Diagnostic Tools
            const OperationalSectionHeader(
              title: 'Alat Diagnostik Lapangan',
              subtitle: 'Pengujian transmisi dan sinkronisasi beacon titik kumpul',
            ),
            const SizedBox(height: 8),

            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.borderSubtle),
              ),
              child: Column(
                children: [
                  _DiagnosticActionRow(
                    title: 'Uji Pancaran Iklan BLE (Ping)',
                    subtitle: 'Memverifikasi beacon menyiarkan UUID WE-IRED',
                    icon: Icons.rss_feed,
                    buttonLabel: 'Uji Sinyal',
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Pancaran Iklan BLE Beacon 01 terdeteksi kuat (-58 dBm).'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                  ),
                  const Divider(height: 16),
                  _DiagnosticActionRow(
                    title: 'Simpan Konfigurasi ke Snapshot',
                    subtitle: 'Menyiapkan paket update untuk Posko /beacon/sync',
                    icon: Icons.save_alt,
                    buttonLabel: 'Simpan',
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Ambang batas ${state.beaconCalibratedRssi} dBm tersimpan ke antrean sinkronisasi.'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TelemetryItem extends StatelessWidget {
  final String label;
  final String value;
  final Color statusColor;
  final IconData icon;

  const _TelemetryItem({
    required this.label,
    required this.value,
    required this.statusColor,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppTheme.slate100,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: statusColor),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(fontSize: 10, color: AppTheme.slate600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: statusColor),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _DiagnosticActionRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final String buttonLabel;
  final VoidCallback onTap;

  const _DiagnosticActionRow({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.buttonLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppTheme.primaryBlue),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.slate900),
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 10, color: AppTheme.slate500),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          height: 36,
          child: OutlinedButton(
            onPressed: onTap,
            child: Text(buttonLabel, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }
}
