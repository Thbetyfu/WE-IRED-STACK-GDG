import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ui/ui.dart';

import '../../app/relawan_state.dart';

class PoskoConnectPage extends ConsumerStatefulWidget {
  const PoskoConnectPage({super.key});

  @override
  ConsumerState<PoskoConnectPage> createState() => _PoskoConnectPageState();
}

class _PoskoConnectPageState extends ConsumerState<PoskoConnectPage> {
  bool _isManualInput = false;
  late final TextEditingController _urlController;
  late final TextEditingController _fingerprintController;

  @override
  void initState() {
    super.initState();
    final state = ref.read(relawanProvider);
    _urlController = TextEditingController(text: state.poskoUrl);
    _fingerprintController = TextEditingController(text: state.poskoFingerprint);
  }

  @override
  void dispose() {
    _urlController.dispose();
    _fingerprintController.dispose();
    super.dispose();
  }

  void _saveManualConfig() {
    ref.read(relawanProvider.notifier).updatePoskoConfig(
          url: _urlController.text.trim(),
          fingerprint: _fingerprintController.text.trim(),
        );
    setState(() => _isManualInput = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Konfigurasi Posko berhasil disimpan secara manual.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _simulateQrScan() {
    // Simulated scan of standard Posko QR JSON payload (FR-PSK-04)
    ref.read(relawanProvider.notifier).updatePoskoConfig(
          url: 'http://weired-posko.local:8080',
          fingerprint: 'SHA256:7A:B2:99:E1:3F:88:21',
          ssid: 'WEIRED-POSKO-RT05',
        );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('QR Posko tervalidasi: Sertifikat TLS Pinning cocok.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(relawanProvider);
    final notifier = ref.read(relawanProvider.notifier);

    return Scaffold(
      backgroundColor: AppTheme.bgCanvas,
      appBar: AppBar(
        title: const Text('Koneksi Posko Lokal'),
        centerTitle: false,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Status Card
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
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: state.isPoskoConnected ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          state.isPoskoConnected ? Icons.wifi : Icons.wifi_off,
                          color: state.isPoskoConnected ? AppTheme.statusAman : AppTheme.statusKritis,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Posko Lokal Standalone (N-16, F-21)',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.slate900),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              state.isPoskoConnected ? 'Terhubung ke Hotspot Wi-Fi Posko' : 'Terputus / Mode Mandiri Offline',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: state.isPoskoConnected ? AppTheme.statusAman : AppTheme.statusKritis,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: state.isPoskoConnected,
                        activeThumbColor: AppTheme.statusAman,
                        onChanged: (val) => notifier.togglePoskoConnection(val),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 10),

                  // Connection Metadata
                  _ConnectionMetaRow(label: 'SSID Wi-Fi', value: state.poskoSsid),
                  const SizedBox(height: 4),
                  _ConnectionMetaRow(label: 'Alamat Endpoint', value: state.poskoUrl),
                  const SizedBox(height: 4),
                  _ConnectionMetaRow(
                    label: 'TLS Fingerprint',
                    value: state.poskoFingerprint,
                    isMonospace: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Scan QR / Pindai Konfigurasi
            OperationalSectionHeader(
              title: 'Konfigurasi Posko via QR (FR-PSK-04)',
              subtitle: 'Pengaturan mDNS, port, dan certificate pinning dari layar Dashboard RT',
              trailing: TextButton.icon(
                icon: Icon(_isManualInput ? Icons.qr_code : Icons.edit_note, size: 16),
                label: Text(
                  _isManualInput ? 'Pindai QR' : 'Input Manual',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                ),
                onPressed: () => setState(() => _isManualInput = !_isManualInput),
              ),
            ),
            const SizedBox(height: 8),

            if (!_isManualInput)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.borderSubtle),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        color: AppTheme.slate100,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.borderStrong),
                      ),
                      child: const Center(
                        child: Icon(Icons.qr_code_scanner, size: 64, color: AppTheme.slate600),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Arahkan Kamera ke QR Dashboard Posko RT',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.slate900),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'QR memuat konfigurasi mDNS, port 8080/8443, dan certificate pinning tanpa membutuhkan akses cloud.',
                      style: TextStyle(fontSize: 11, color: AppTheme.slate500, height: 1.3),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.camera_alt_outlined, size: 16),
                        label: const Text(
                          'Pindai QR Kode Sekarang',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                        ),
                        onPressed: _simulateQrScan,
                      ),
                    ),
                  ],
                ),
              )
            else
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
                    const Text(
                      'URL Endpoint Posko:',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.slate700),
                    ),
                    const SizedBox(height: 4),
                    TextField(
                      controller: _urlController,
                      decoration: const InputDecoration(
                        hintText: 'http://192.168.4.1:8080 atau mDNS',
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Sidik Jari Sertifikat TLS (SHA256):',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.slate700),
                    ),
                    const SizedBox(height: 4),
                    TextField(
                      controller: _fingerprintController,
                      decoration: const InputDecoration(
                        hintText: 'SHA256:XX:XX:...',
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.check, size: 16),
                        label: const Text('Simpan Konfigurasi'),
                        onPressed: _saveManualConfig,
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 20),

            // Two-Way Sync Operations (Push & Pull)
            const OperationalSectionHeader(
              title: 'Operasi Sinkronisasi Dua Arah',
              subtitle: 'Pertukaran data antara HP relawan dan server Posko RT',
            ),
            const SizedBox(height: 8),

            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 52,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.cloud_upload_outlined, size: 16),
                      label: const Text(
                        'Unggah (Push)',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onPressed: state.isPoskoConnected
                          ? () {
                              notifier.syncCollectedPackets();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Paket kolektor & outbox proksi berhasil diunggah ke Posko.'),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          : null,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SizedBox(
                    height: 52,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.cloud_download_outlined, size: 16),
                      label: const Text(
                        'Unduh (Pull)',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onPressed: state.isPoskoConnected
                          ? () {
                              notifier.pullSyncFromPosko();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Pembaruan triase & penugasan tugas ditarik dari Posko.'),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          : null,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Sync Timestamps
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.borderSubtle),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(
                        child: Text(
                          'Sinkronisasi Terakhir (Push/Pull):',
                          style: TextStyle(fontSize: 11, color: AppTheme.slate600),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        state.lastSyncTime != null
                            ? '${state.lastSyncTime!.hour.toString().padLeft(2, '0')}:${state.lastSyncTime!.minute.toString().padLeft(2, '0')}'
                            : 'Belum pernah',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.slate900),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'Protokol Pertukaran:',
                          style: TextStyle(fontSize: 11, color: AppTheme.slate600),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      SizedBox(width: 8),
                      Text(
                        'HTTP/2 REST (N-16)',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppTheme.slate800),
                      ),
                    ],
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

class _ConnectionMetaRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isMonospace;

  const _ConnectionMetaRow({
    required this.label,
    required this.value,
    this.isMonospace = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 105,
          child: Text(
            label,
            style: const TextStyle(fontSize: 11, color: AppTheme.slate500),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              fontFamily: isMonospace ? 'monospace' : null,
              color: AppTheme.slate800,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
