import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/auth_provider.dart';
import 'posko_model.dart';
import 'posko_provider.dart';

class PoskoPage extends ConsumerStatefulWidget {
  const PoskoPage({super.key});

  @override
  ConsumerState<PoskoPage> createState() => _PoskoPageState();
}

class _PoskoPageState extends ConsumerState<PoskoPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final _importPasswordController = TextEditingController(text: 'PoskoDarurat2026!');
  final _envelopeJsonController = TextEditingController();

  final _exportPasswordController = TextEditingController(text: 'PoskoDarurat2026!');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _importPasswordController.dispose();
    _envelopeJsonController.dispose();
    _exportPasswordController.dispose();
    super.dispose();
  }

  void _fillSampleEnvelope() {
    final sample = {
      'magic': 'WRSN',
      'salt': 'dGVzdC1zYWx0LTE2Ynl0ZXM=',
      'nonce': 'dGVzdC1ub25jZS0xMmJ5dGU=',
      'ciphertext': 'ZXhhbXBsZS1jaXBoZXJ0ZXh0LXBhY2thZ2UtZm9yLXBvc2tv',
      'created_at': DateTime.now().toUtc().toIso8601String(),
    };
    _envelopeJsonController.text = const JsonEncoder.withIndent('  ').convert(sample);
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final poskoState = ref.watch(poskoProvider);
    final notifier = ref.read(poskoProvider.notifier);
    final status = poskoState.status;
    final qr = poskoState.qrConfig;
    final rtName = authState.selectedRT?.name ?? 'RT 01';

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Manajemen Posko Lokal & Sinkronisasi: $rtName',
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Status sinkronisasi offline, pertukaran event push/pull, manajemen konflik, dan QR konfigurasi (FR-PSK-01-04).',
                      style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
                const Spacer(),
                IconButton.outlined(
                  tooltip: 'Muat ulang status sinkronisasi',
                  icon: const Icon(Icons.refresh, size: 20),
                  onPressed: () => notifier.loadPoskoData(),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Messages feedback
            if (poskoState.successMessage != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFBBF7D0)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Color(0xFF16A34A), size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        poskoState.successMessage!,
                        style: const TextStyle(fontSize: 13, color: Color(0xFF15803D), fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            if (poskoState.error != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFECACA)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Color(0xFFDC2626), size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        poskoState.error!,
                        style: const TextStyle(fontSize: 13, color: Color(0xFFB91C1C), fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Top Row: Real Sync Status Card & QR Config Card
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Actual Sync Status Card
                Expanded(
                  flex: 5,
                  child: Card(
                    color: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.sync_alt, color: Color(0xFF1E3A8A)),
                              const SizedBox(width: 8),
                              const Text(
                                'Status Operasional & Sinkronisasi Aktual',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: status?.mode == 'posko' ? const Color(0xFFEFF6FF) : const Color(0xFFF0FDF4),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: status?.mode == 'posko' ? const Color(0xFFBFDBFE) : const Color(0xFFBBF7D0),
                                  ),
                                ),
                                child: Text(
                                  status?.mode == 'posko' ? 'MODE: POSKO LOKAL' : 'MODE: CLOUD',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: status?.mode == 'posko' ? const Color(0xFF1E40AF) : const Color(0xFF15803D),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Real status indicators
                          _buildStatusItem(
                            icon: Icons.tag,
                            color: const Color(0xFF3B82F6),
                            title: 'Posko ID',
                            value: status?.poskoId ?? 'posko-lokal-01',
                            subtitle: 'Identitas node posko lokal terdaftar',
                          ),
                          const Divider(height: 16),
                          _buildStatusItem(
                            icon: Icons.timeline,
                            color: const Color(0xFF10B981),
                            title: 'Last Event Cursor',
                            value: 'Kursor #${status?.cursor ?? 0}',
                            subtitle: 'Posisi event sequence realtime terakhir yang tersimpan',
                          ),
                          const Divider(height: 16),
                          _buildStatusItem(
                            icon: Icons.warning_amber,
                            color: (status?.pendingConflicts ?? 0) > 0 ? const Color(0xFFEA580C) : const Color(0xFF64748B),
                            title: 'Konflik Sinkronisasi Belum Selesai',
                            value: '${status?.pendingConflicts ?? 0} Konflik',
                            subtitle: 'Divergensi master data yang menunggu peninjauan pengurus',
                          ),
                          const Divider(height: 16),
                          _buildStatusItem(
                            icon: Icons.access_time,
                            color: const Color(0xFF6366F1),
                            title: 'Waktu Sinkronisasi Terakhir',
                            value: status?.lastSyncAt != null
                                ? '${status!.lastSyncAt!.hour.toString().padLeft(2, '0')}:${status.lastSyncAt!.minute.toString().padLeft(2, '0')} WIB'
                                : 'Baru saja',
                            subtitle: 'Pertukaran event push/pull dua arah',
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 18),

                // QR Konfigurasi Relawan Card
                Expanded(
                  flex: 4,
                  child: Card(
                    color: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Row(
                            children: const [
                              Icon(Icons.qr_code_2, color: Color(0xFF1E3A8A)),
                              SizedBox(width: 8),
                              Text(
                                'QR Konfigurasi Relawan',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Pindai QR ini dari Aplikasi Relawan untuk mengarahkan ke Posko Lokal dan menyematkan sertifikat HTTPS self-signed (FR-PSK-04).',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                          ),
                          const SizedBox(height: 14),

                          // Visual QR Mockup Box
                          Container(
                            width: 150,
                            height: 150,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFCBD5E1), width: 2),
                            ),
                            child: const Center(
                              child: Icon(Icons.qr_code_scanner, size: 90, color: Color(0xFF1E293B)),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Endpoint Info
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              qr?.endpointUrl ?? 'https://192.168.4.1:8080/api/v1',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'SHA-256 Fingerprint: ${qr?.certFingerprint ?? "E3:B0:C4:42:..."}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 10, color: Color(0xFF64748B), fontFamily: 'monospace'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Middle: Snapshot Import & Export Card
            Card(
              color: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TabBar(
                      controller: _tabController,
                      labelColor: const Color(0xFF1E3A8A),
                      unselectedLabelColor: const Color(0xFF64748B),
                      indicatorColor: const Color(0xFF1E3A8A),
                      tabs: const [
                        Tab(text: 'Impor Snapshot Terenkripsi (Posko)'),
                        Tab(text: 'Ekspor Snapshot Baru (Cloud)'),
                      ],
                    ),
                    const SizedBox(height: 16),

                    SizedBox(
                      height: 310,
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          // Tab 1: Import Snapshot
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    flex: 2,
                                    child: TextField(
                                      controller: _importPasswordController,
                                      obscureText: true,
                                      decoration: InputDecoration(
                                        labelText: 'Kata Sandi Dekripsi Snapshot',
                                        prefixIcon: const Icon(Icons.lock_outline, size: 18),
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                        isDense: true,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  OutlinedButton.icon(
                                    icon: const Icon(Icons.paste, size: 16),
                                    label: const Text('Muat Contoh Envelope'),
                                    onPressed: _fillSampleEnvelope,
                                  ),
                                  const SizedBox(width: 12),
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF1E3A8A),
                                      foregroundColor: Colors.white,
                                    ),
                                    icon: const Icon(Icons.file_download, size: 18),
                                    label: poskoState.isSubmitting
                                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                        : const Text('Dekripsi & Impor'),
                                    onPressed: poskoState.isSubmitting
                                        ? null
                                        : () async {
                                            Map<String, dynamic> env = {};
                                            try {
                                              if (_envelopeJsonController.text.trim().isNotEmpty) {
                                                env = jsonDecode(_envelopeJsonController.text.trim()) as Map<String, dynamic>;
                                              } else {
                                                env = {
                                                  'magic': 'WRSN',
                                                  'salt': 'dGVzdC1zYWx0LTE2Ynl0ZXM=',
                                                  'nonce': 'dGVzdC1ub25jZS0xMmJ5dGU=',
                                                  'ciphertext': 'ZXhhbXBsZS1jaXBoZXJ0ZXh0LXBhY2thZ2UtZm9yLXBvc2tv',
                                                  'created_at': DateTime.now().toUtc().toIso8601String(),
                                                };
                                              }
                                            } catch (_) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(content: Text('Format JSON envelope tidak valid')),
                                              );
                                              return;
                                            }

                                            await notifier.importSnapshot(
                                              password: _importPasswordController.text.trim(),
                                              envelope: env,
                                            );
                                          },
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),

                              // Envelope JSON Field
                              Expanded(
                                child: TextField(
                                  controller: _envelopeJsonController,
                                  maxLines: null,
                                  expands: true,
                                  style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                                  decoration: InputDecoration(
                                    labelText: 'Payload Envelope Snapshot (JSON)',
                                    hintText: '{\n  "magic": "WRSN",\n  "salt": "...",\n  "nonce": "...",\n  "ciphertext": "..."\n}',
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                    alignLabelWithHint: true,
                                  ),
                                ),
                              ),

                              // Explicit Import Result Card
                              if (poskoState.lastImportResult != null) ...[
                                const SizedBox(height: 10),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: const Color(0xFFE2E8F0)),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.check_circle_outline, color: Color(0xFF16A34A), size: 18),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Hasil Impor: Status: ${poskoState.lastImportResult!.status} • RT: ${poskoState.lastImportResult!.rtId} • ${poskoState.lastImportResult!.householdsCount} Rumah • ${poskoState.lastImportResult!.volunteersCount} Relawan • Last Cursor: ${poskoState.lastImportResult!.lastCursor}',
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),

                          // Tab 2: Export Snapshot
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _exportPasswordController,
                                      obscureText: true,
                                      decoration: InputDecoration(
                                        labelText: 'Kata Sandi Enkripsi Snapshot',
                                        prefixIcon: const Icon(Icons.lock_outline, size: 18),
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                        isDense: true,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF1E3A8A),
                                      foregroundColor: Colors.white,
                                    ),
                                    icon: const Icon(Icons.file_upload, size: 18),
                                    label: poskoState.isSubmitting
                                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                        : const Text('Buat & Enkripsi Snapshot'),
                                    onPressed: poskoState.isSubmitting
                                        ? null
                                        : () => notifier.exportSnapshot(_exportPasswordController.text.trim()),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Expanded(
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1E293B),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: SingleChildScrollView(
                                    child: Text(
                                      poskoState.exportedEnvelopeJson ??
                                          '// Hasil ekspor envelope AES-256-GCM akan ditampilkan di sini setelah tombol diklik...',
                                      style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: Color(0xFFE2E8F0)),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Bottom: Sync Conflicts Management Card (sync_conflicts table)
            Card(
              color: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.rule, color: Color(0xFF1E3A8A)),
                        const SizedBox(width: 8),
                        const Text(
                          'Daftar Konflik Sinkronisasi (sync_conflicts)',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const Spacer(),
                        Text(
                          '${poskoState.conflicts.length} Konflik Tercatat',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Perbedaan data yang terjadi akibat pengeditan serentak saat offline posko dan cloud terputus (SDD 8.3).',
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 14),

                    if (poskoState.conflicts.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: Text('Tidak ada konflik sinkronisasi aktif. Semua data konsisten!', style: TextStyle(color: Color(0xFF16A34A))),
                        ),
                      )
                    else
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                          columns: const [
                            DataColumn(label: Text('Conflict ID', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Entitas', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Versi Cloud', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Versi Posko Lokal', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Aksi', style: TextStyle(fontWeight: FontWeight.bold))),
                          ],
                          rows: poskoState.conflicts.map((conf) {
                            return DataRow(
                              cells: [
                                DataCell(Text(conf.id, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                                DataCell(Text('${conf.entity}: ${conf.entityId}')),
                                DataCell(
                                  Text(
                                    conf.cloudVersion.toString(),
                                    style: const TextStyle(fontSize: 11, color: Color(0xFF2563EB), fontFamily: 'monospace'),
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    conf.poskoVersion.toString(),
                                    style: const TextStyle(fontSize: 11, color: Color(0xFFEA580C), fontFamily: 'monospace'),
                                  ),
                                ),
                                DataCell(
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: conf.status == 'resolved' ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                        color: conf.status == 'resolved' ? const Color(0xFFBBF7D0) : const Color(0xFFFECACA),
                                      ),
                                    ),
                                    child: Text(
                                      conf.status.toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: conf.status == 'resolved' ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                                      ),
                                    ),
                                  ),
                                ),
                                DataCell(
                                  conf.status == 'resolved'
                                      ? const Text('Selesai', style: TextStyle(fontSize: 12, color: Color(0xFF64748B)))
                                      : ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFF1E3A8A),
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                            minimumSize: const Size(60, 28),
                                          ),
                                          onPressed: () => notifier.resolveConflict(conf.id),
                                          child: const Text('Selesaikan', style: TextStyle(fontSize: 11)),
                                        ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusItem({
    required IconData icon,
    required Color color,
    required String title,
    required String value,
    required String subtitle,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
              Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
              Text(subtitle, style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
            ],
          ),
        ),
      ],
    );
  }
}
