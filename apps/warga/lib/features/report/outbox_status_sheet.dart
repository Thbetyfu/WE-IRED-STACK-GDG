import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core/core.dart';
import 'package:ui/ui.dart';

import '../../app/warga_state.dart';

/// Modal sheet inspecting outbox queue & actual delivery statuses (FR-SYNC-01, FR-RPT-05..06)
class OutboxStatusSheet extends ConsumerWidget {
  const OutboxStatusSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const OutboxStatusSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(wargaProvider);
    final notifier = ref.read(wargaProvider.notifier);
    final outbox = state.outbox;
    final pendingCount = state.pendingOutboxCount;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
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
                      color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.outbox, color: AppTheme.primaryBlue, size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Antrean Pengiriman Laporan',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.slate900),
                        ),
                        Text(
                          'Penyimpanan Transaksional Outbox (FR-SYNC-01)',
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
              const Divider(height: 20),

              // Network Connection Mode Indicator
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.slate50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.borderSubtle),
                ),
                child: Row(
                  children: [
                    Icon(
                      state.connectionMode == ConnectionMode.online
                          ? Icons.cloud_done
                          : (state.connectionMode == ConnectionMode.meshRelay ? Icons.bluetooth_connected : Icons.cloud_off),
                      size: 20,
                      color: state.connectionMode == ConnectionMode.online
                          ? AppTheme.statusAman
                          : (state.connectionMode == ConnectionMode.meshRelay ? AppTheme.primaryBlue : const Color(0xFFD97706)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            state.connectionMode == ConnectionMode.online
                                ? 'Koneksi: Internet / Wi-Fi Posko Aktif'
                                : (state.connectionMode == ConnectionMode.meshRelay
                                    ? 'Koneksi: BLE Mesh Relay Relawan'
                                    : 'Koneksi: Luring Total (Offline)'),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.slate900),
                          ),
                          Text(
                            pendingCount > 0
                                ? '$pendingCount laporan tersimpan di memori perangkat menanti jaringan.'
                                : 'Semua paket laporan telah tersinkronisasi.',
                            style: const TextStyle(fontSize: 11, color: AppTheme.slate600),
                          ),
                        ],
                      ),
                    ),
                    if (pendingCount > 0 && state.connectionMode != ConnectionMode.offline)
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryBlue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                        onPressed: () {
                          notifier.syncPendingOutbox();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Menyinkronkan seluruh item antrean outbox...'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                        child: const Text('Sinkronkan'),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Outbox Items List
              if (outbox.isEmpty)
                Container(
                  padding: const EdgeInsets.all(24),
                  alignment: Alignment.center,
                  child: Column(
                    children: [
                      const Icon(Icons.inventory_2_outlined, size: 40, color: AppTheme.slate400),
                      const SizedBox(height: 8),
                      const Text(
                        'Belum Ada Riwayat Antrean',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.slate700),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Setiap laporan kondisi darurat akan dicatat secara transaksional di sini.',
                        style: TextStyle(fontSize: 11, color: AppTheme.slate500),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              else ...[
                const Text(
                  'Riwayat & Antrean Paket Laporan:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.slate900),
                ),
                const SizedBox(height: 10),
                ...outbox.map((item) {
                  final report = item.report;
                  final statusColor = item.deliveryStatus == DeliveryStatus.terkirim
                      ? AppTheme.statusAman
                      : (item.deliveryStatus == DeliveryStatus.diteruskanRelay
                          ? AppTheme.primaryBlue
                          : const Color(0xFFD97706));

                  final statusBg = item.deliveryStatus == DeliveryStatus.terkirim
                      ? const Color(0xFFDCFCE7)
                      : (item.deliveryStatus == DeliveryStatus.diteruskanRelay
                          ? const Color(0xFFEFF6FF)
                          : const Color(0xFFFEF3C7));

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
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
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: statusBg,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    item.deliveryStatus == DeliveryStatus.terkirim
                                        ? Icons.check_circle
                                        : (item.deliveryStatus == DeliveryStatus.diteruskanRelay
                                            ? Icons.sensors
                                            : Icons.save_outlined),
                                    size: 13,
                                    color: statusColor,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    item.statusLabel.toUpperCase(),
                                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor),
                                  ),
                                ],
                              ),
                            ),
                            const Spacer(),
                            Text(
                              'Seq #${report.seq} • ${item.payloadSizeBytes} bytes',
                              style: const TextStyle(fontSize: 10, color: AppTheme.slate500, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          ReportStatus.label(report.status),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.slate900),
                        ),
                        if (report.message != null && report.message!.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            '"${report.message}"',
                            style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: AppTheme.slate700),
                          ),
                        ],
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Text(
                              'Kanal: ${item.channel.toUpperCase()}',
                              style: const TextStyle(fontSize: 10, color: AppTheme.slate500),
                            ),
                            if (item.relayHopNode != null) ...[
                              const Text(' • ', style: TextStyle(color: AppTheme.slate400, fontSize: 10)),
                              Text(
                                'Via: ${item.relayHopNode}',
                                style: const TextStyle(fontSize: 10, color: AppTheme.primaryBlue, fontWeight: FontWeight.w600),
                              ),
                            ],
                            const Spacer(),
                            if (item.deliveryStatus == DeliveryStatus.tersimpanLokal)
                              TextButton(
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  minimumSize: const Size(50, 24),
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                onPressed: () => notifier.retryOutboxItem(item.id),
                                child: const Text('Coba Kirim', style: TextStyle(fontSize: 11)),
                              ),
                          ],
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
