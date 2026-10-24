import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ui/ui.dart';

import '../../app/relawan_state.dart';

class CollectorPage extends ConsumerWidget {
  const CollectorPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(relawanProvider);
    final notifier = ref.read(relawanProvider.notifier);

    return Scaffold(
      backgroundColor: AppTheme.bgCanvas,
      appBar: AppBar(
        title: const Text('Mode Kolektor (Data Mule BLE)'),
        centerTitle: false,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Header Info Card with Technical Scope Note
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.borderSubtle),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.bluetooth_searching, color: AppTheme.primaryBlue, size: 24),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Kolektor Laporan Offline (FR-BLE-02)',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.slate900),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Saat Anda berkeliling blok, HP Anda otomatis menampung paket relay biner 46-byte dari HP warga sekitar untuk dibawa ke Posko (Data Mule).',
                          style: TextStyle(fontSize: 11, color: AppTheme.slate600, height: 1.3),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // 1. HARDWARE STATUS CARD: BLUETOOTH RADIO
            Container(
              padding: const EdgeInsets.all(14),
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
                          'Status Perangkat Bluetooth',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.slate900),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _BluetoothStatusBadge(status: state.bluetoothRadioStatus),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    state.bluetoothRadioStatus == BluetoothRadioStatus.active
                        ? 'Radio Bluetooth aktif dan siap menerima paket iklan BLE warga.'
                        : state.bluetoothRadioStatus == BluetoothRadioStatus.disabled
                            ? 'Radio Bluetooth mati di pengaturan HP. Hidupkan Bluetooth untuk mengumpulkan paket.'
                            : 'Izin Bluetooth runtime belum diberikan atau menunggu pengujian lapangan.',
                    style: const TextStyle(fontSize: 11, color: AppTheme.slate600),
                  ),
                  const SizedBox(height: 10),
                  // Radio State Selector with Wrap to avoid overflow
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      const Text('Diagnostik Radio:', style: TextStyle(fontSize: 10, color: AppTheme.slate500)),
                      _RadioChoiceBtn(
                        label: 'Aktif',
                        isActive: state.bluetoothRadioStatus == BluetoothRadioStatus.active,
                        onTap: () => notifier.setBluetoothRadioStatus(BluetoothRadioStatus.active),
                      ),
                      _RadioChoiceBtn(
                        label: 'Mati',
                        isActive: state.bluetoothRadioStatus == BluetoothRadioStatus.disabled,
                        onTap: () => notifier.setBluetoothRadioStatus(BluetoothRadioStatus.disabled),
                      ),
                      _RadioChoiceBtn(
                        label: 'Belum Diuji',
                        isActive: state.bluetoothRadioStatus == BluetoothRadioStatus.unverified,
                        onTap: () => notifier.setBluetoothRadioStatus(BluetoothRadioStatus.unverified),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // 2. SCAN CYCLE TOGGLE (FR-BLE-10)
            Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.borderSubtle),
                ),
                child: SwitchListTile(
                  value: state.isCollectorScanning && state.bluetoothRadioStatus == BluetoothRadioStatus.active,
                  activeThumbColor: AppTheme.statusAman,
                  title: const Text('Siklus Pemindaian Agresif (FR-BLE-10)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  subtitle: const Text(
                    'Pola duty-cycle 8 detik aktif / 4 detik siaga untuk menarik paket relay warga tanpa menguras baterai HP (<3% per jam).',
                    style: TextStyle(fontSize: 11, color: AppTheme.slate600, height: 1.25),
                  ),
                  onChanged: state.bluetoothRadioStatus == BluetoothRadioStatus.active
                      ? (val) => notifier.toggleCollectorScanning(val)
                      : null,
                ),
              ),
            ),
            const SizedBox(height: 14),

            // 3. BUFFER METRICS & STORAGE PROGRESS
            Container(
              padding: const EdgeInsets.all(14),
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
                          'Kapasitas Buffer HP',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.slate900),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${state.collectedPacketsCount} / 500 Paket',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.primaryBlue),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: (state.collectedPacketsCount / 500).clamp(0.0, 1.0),
                      backgroundColor: AppTheme.slate100,
                      valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryBlue),
                      minHeight: 8,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Penyimpanan lokal SQLite (NFR-REL-01). Data biner terenkripsi AES-128-GCM dengan kunci rumah dan tanda tangan Ed25519 (SDD 7.2).',
                    style: TextStyle(fontSize: 10, color: AppTheme.slate500),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // 4. CONNECTION AND SYNC STATUS
            Row(
              children: [
                Expanded(
                  child: OperationalMetricTile(
                    label: 'Paket Belum Sinkron',
                    value: '${state.collectedPacketsCount}',
                    subtitle: 'Siap diantar ke Posko',
                    icon: Icons.inventory_2_outlined,
                    accentColor: AppTheme.statusTitikKumpul,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OperationalMetricTile(
                    label: 'Status Hotspot Posko',
                    value: state.isPoskoConnected ? 'Terhubung' : 'Terputus',
                    subtitle: state.isPoskoConnected ? 'Wi-Fi Posko Aktif' : 'Beroperasi Mandiri',
                    icon: Icons.router,
                    accentColor: state.isPoskoConnected ? AppTheme.statusAman : AppTheme.statusKritis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // SYNC BUTTON (Min 52dp touch target)
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.cloud_upload_outlined),
                label: Text(
                  state.collectedPacketsCount > 0
                      ? 'SINKRONKAN ${state.collectedPacketsCount} PAKET KE POSKO SEKARANG'
                      : 'SEMUA PAKET TELAH TERSINKRON',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                onPressed: state.collectedPacketsCount > 0
                    ? () {
                        notifier.syncCollectedPackets();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Paket relay dan outbox berhasil disinkronkan ke endpoint /sync/relay-packets.'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    : null,
              ),
            ),
            const SizedBox(height: 20),

            // 5. PACKET BUFFER LOG
            OperationalSectionHeader(
              title: 'Daftar Paket Dalam Buffer (${state.packetBuffer.length})',
              subtitle: 'Data terenkripsi yang ditampung dari perangkat warga',
            ),
            const SizedBox(height: 8),

            if (state.packetBuffer.isEmpty)
              Container(
                padding: const EdgeInsets.all(20),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.borderSubtle),
                ),
                child: const Text(
                  'Buffer kosong. Berkelilinglah di blok penugasan untuk menampung paket warga.',
                  style: TextStyle(fontSize: 12, color: AppTheme.slate500),
                  textAlign: TextAlign.center,
                ),
              )
            else
              ...state.packetBuffer.map((pkt) => _PacketCard(packet: pkt)),

            const SizedBox(height: 16),

            // Technical Dependency Disclosure Badge
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.slate100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.borderSubtle),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.integration_instructions_outlined, size: 14, color: AppTheme.slate600),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Catatan Dependensi Modul Hardware (J-18, ble_relay):',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppTheme.slate700),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Penerimaan paket aktual mengandalkan binding modul native ble_relay (Joshua). UI ini terhubung ke antrean Outbox & Buffer kolektor sesuai kontrak SDD 7.2.',
                    style: TextStyle(fontSize: 10, color: AppTheme.slate500),
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

class _BluetoothStatusBadge extends StatelessWidget {
  final BluetoothRadioStatus status;

  const _BluetoothStatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    String text;

    switch (status) {
      case BluetoothRadioStatus.active:
        bg = const Color(0xFFDCFCE7);
        fg = AppTheme.statusAman;
        text = 'Aktif (Siaga)';
        break;
      case BluetoothRadioStatus.disabled:
        bg = const Color(0xFFFEE2E2);
        fg = AppTheme.statusKritis;
        text = 'Nonaktif';
        break;
      case BluetoothRadioStatus.unverified:
        bg = const Color(0xFFFEF3C7);
        fg = const Color(0xFFB45309);
        text = 'Belum Diuji';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: fg),
      ),
    );
  }
}

class _RadioChoiceBtn extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _RadioChoiceBtn({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isActive ? AppTheme.primaryBlue : AppTheme.slate100,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: isActive ? Colors.white : AppTheme.slate700,
          ),
        ),
      ),
    );
  }
}

class _PacketCard extends StatelessWidget {
  final RelayPacketItem packet;

  const _PacketCard({required this.packet});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primaryBlue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(Icons.data_object, size: 18, color: AppTheme.primaryBlue),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${packet.packetId} • ${packet.source}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.slate900),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Hop: ${packet.hopCount} • RSSI: ${packet.rssi} dBm • ${packet.timeAgo}',
                  style: const TextStyle(fontSize: 10, color: AppTheme.slate500),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: packet.syncStatus == 'Tersinkron' ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              packet.syncStatus,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: packet.syncStatus == 'Tersinkron' ? AppTheme.statusAman : const Color(0xFFB45309),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
