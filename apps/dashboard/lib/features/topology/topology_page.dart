import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ui/ui.dart';

import '../../app/auth_provider.dart';

class TopologyPage extends ConsumerWidget {
  const TopologyPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Page Header
            OperationalPageHeader(
              title: 'Topologi Jaringan Mesh BLE: ${authState.selectedRT?.name ?? "RT 05"}',
              subtitle: 'Pemantauan node pembawa data (data mule), status relay multi-hop, dan paket laporan luring yang terkumpul (FR-BLE-09, SDD 7.5).',
              actions: const [
                DemoDataBadge(note: 'KONSOL RELAY BLE SIMULASI / LAB'),
              ],
            ),
            const SizedBox(height: 20),

            // Top Status Metrics
            LayoutBuilder(
              builder: (context, constraints) {
                final totalWidth = constraints.maxWidth;
                final t1 = OperationalMetricTile(
                  label: 'Node Relawan Aktif',
                  value: '3 Node',
                  subtitle: '2 Relawan Lapangan + 1 Posko Gateway',
                  icon: Icons.hub,
                  accentColor: AppTheme.primaryBlue,
                );
                final t2 = OperationalMetricTile(
                  label: 'Paket Luring Terkumpul',
                  value: '18 Paket',
                  subtitle: 'Format biner 46-byte (HMAC terverifikasi)',
                  icon: Icons.inventory_2,
                  accentColor: AppTheme.statusTitikKumpul,
                );
                final t3 = OperationalMetricTile(
                  label: 'Rata-rata Hop ke Posko',
                  value: '1.4 Hop',
                  subtitle: 'Maksimum batas TTL: 6 Hop (FR-BLE-06)',
                  icon: Icons.alt_route,
                  accentColor: AppTheme.statusAman,
                );
                final t4 = OperationalMetricTile(
                  label: 'Status Beacon Titik Kumpul',
                  value: 'Tersinkron',
                  subtitle: 'ESP32-S3 BLE Advert (Sync terakhir 1m lalu)',
                  icon: Icons.wifi_tethering,
                  accentColor: const Color(0xFF0D9488),
                );

                if (totalWidth >= 950) {
                  return Row(
                    children: [
                      Expanded(child: t1),
                      const SizedBox(width: 14),
                      Expanded(child: t2),
                      const SizedBox(width: 14),
                      Expanded(child: t3),
                      const SizedBox(width: 14),
                      Expanded(child: t4),
                    ],
                  );
                }

                final tileWidth = (totalWidth - 14) / 2;
                return Wrap(
                  spacing: 14,
                  runSpacing: 14,
                  children: [
                    SizedBox(width: tileWidth, child: t1),
                    SizedBox(width: tileWidth, child: t2),
                    SizedBox(width: tileWidth, child: t3),
                    SizedBox(width: tileWidth, child: t4),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),

            // Node List & Relay Path Inspector
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 950;

                final activeNodes = Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.borderSubtle),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const OperationalSectionHeader(
                        title: 'Daftar Node Mesh Lapangan Aktif',
                        subtitle: 'Perangkat relawan dan beacon yang bertindak sebagai jembatan data offline',
                      ),
                      const SizedBox(height: 8),
                      _NodeItem(
                        nodeId: 'NODE-REL-01',
                        role: 'HP Relawan (Kolektor Data Mule)',
                        personName: 'Budi Santoso (Blok A)',
                        rssi: -62,
                        packetCount: 9,
                        hopToPosko: 1,
                        batteryLevel: 82,
                        isOnline: true,
                      ),
                      const SizedBox(height: 10),
                      _NodeItem(
                        nodeId: 'NODE-REL-02',
                        role: 'HP Relawan (Mesh Multi-hop)',
                        personName: 'Siti Aminah (Blok B)',
                        rssi: -75,
                        packetCount: 5,
                        hopToPosko: 2,
                        batteryLevel: 68,
                        isOnline: true,
                      ),
                      const SizedBox(height: 10),
                      _NodeItem(
                        nodeId: 'NODE-BCN-01',
                        role: 'WE-IRED Beacon ESP32-S3',
                        personName: 'Balai RW / Titik Kumpul Utama',
                        rssi: -54,
                        packetCount: 4,
                        hopToPosko: 1,
                        batteryLevel: 94,
                        isOnline: true,
                        isHardwareBeacon: true,
                      ),
                    ],
                  ),
                );

                final relayVisualizer = Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.slate900,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.slate800),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.route, color: Color(0xFF38BDF8), size: 18),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Visualisasi Aliran Paket Relay',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Bagaimana laporan warga tanpa sinyal sampai ke Posko',
                        style: TextStyle(color: AppTheme.slate400, fontSize: 11),
                      ),
                      const SizedBox(height: 20),

                      _RelayStep(
                        stepNumber: '1',
                        title: 'HP Warga Melapor (Offline)',
                        detail: 'Laporan dikemas dalam biner 46-byte + HMAC rumah',
                        icon: Icons.phone_android,
                        isDone: true,
                      ),
                      _RelayDivider(),
                      _RelayStep(
                        stepNumber: '2',
                        title: 'Relay Bluetooth ke Relawan',
                        detail: 'Relawan melintas radius BLE (~10-25m), pertukaran LUV',
                        icon: Icons.bluetooth_searching,
                        isDone: true,
                      ),
                      _RelayDivider(),
                      _RelayStep(
                        stepNumber: '3',
                        title: 'Beacon Titik Kumpul / Multi-hop',
                        detail: 'Paket diteruskan antar-node hingga mencapai jangkauan',
                        icon: Icons.router,
                        isDone: true,
                      ),
                      _RelayDivider(),
                      _RelayStep(
                        stepNumber: '4',
                        title: 'Posko Lokal / Dashboard Cloud',
                        detail: 'Sinkronisasi batch, verifikasi HMAC, dan pembaruan triase',
                        icon: Icons.dashboard,
                        isDone: true,
                        isLast: true,
                      ),
                    ],
                  ),
                );

                if (isWide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 3, child: activeNodes),
                      const SizedBox(width: 20),
                      Expanded(flex: 2, child: relayVisualizer),
                    ],
                  );
                }

                return Column(
                  children: [
                    activeNodes,
                    const SizedBox(height: 20),
                    relayVisualizer,
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _NodeItem extends StatelessWidget {
  final String nodeId;
  final String role;
  final String personName;
  final int rssi;
  final int packetCount;
  final int hopToPosko;
  final int batteryLevel;
  final bool isOnline;
  final bool isHardwareBeacon;

  const _NodeItem({
    required this.nodeId,
    required this.role,
    required this.personName,
    required this.rssi,
    required this.packetCount,
    required this.hopToPosko,
    required this.batteryLevel,
    required this.isOnline,
    this.isHardwareBeacon = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.slate50,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isHardwareBeacon ? const Color(0xFFCCFBF1) : const Color(0xFFE0E7FF),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              isHardwareBeacon ? Icons.memory : Icons.smartphone,
              color: isHardwareBeacon ? const Color(0xFF0D9488) : const Color(0xFF4F46E5),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        personName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.slate900),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppTheme.slate200,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        nodeId,
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppTheme.slate700),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  role,
                  style: const TextStyle(fontSize: 11, color: AppTheme.slate500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$packetCount Paket • $hopToPosko Hop',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.slate800),
              ),
              const SizedBox(height: 2),
              Text(
                'RSSI $rssi dBm • Bat: $batteryLevel%',
                style: const TextStyle(fontSize: 10, color: AppTheme.slate500),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RelayStep extends StatelessWidget {
  final String stepNumber;
  final String title;
  final String detail;
  final IconData icon;
  final bool isDone;
  final bool isLast;

  const _RelayStep({
    required this.stepNumber,
    required this.title,
    required this.detail,
    required this.icon,
    required this.isDone,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: isDone ? const Color(0xFF0284C7) : AppTheme.slate700,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Icon(icon, size: 14, color: Colors.white),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 2),
              Text(
                detail,
                style: const TextStyle(color: AppTheme.slate400, fontSize: 11),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RelayDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 12),
      width: 2,
      height: 20,
      color: const Color(0xFF0284C7).withValues(alpha: 0.4),
    );
  }
}
