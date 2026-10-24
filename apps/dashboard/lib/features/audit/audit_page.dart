import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/auth_provider.dart';
import 'audit_model.dart';
import 'audit_provider.dart';

class AuditPage extends ConsumerWidget {
  const AuditPage({super.key});

  void _showDetailDialog(BuildContext context, AuditLogItem log) {
    final prettyDetails = const JsonEncoder.withIndent('  ').convert(log.details);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        title: Row(
          children: [
            const Icon(Icons.security, color: Color(0xFF1E3A8A)),
            const SizedBox(width: 8),
            Text('Detail Audit: ${log.action}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDialogRow('Log ID:', log.id),
              _buildDialogRow('Waktu:', log.createdAt.toLocal().toString()),
              _buildDialogRow('User ID:', log.userId),
              _buildDialogRow('Entitas:', '${log.entity} (${log.entityId})'),
              _buildDialogRow('IP Address:', log.ipAddress),
              _buildDialogRow('User Agent:', log.userAgent.isEmpty ? '-' : log.userAgent),
              const SizedBox(height: 12),
              const Text('Payload Details:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  prettyDetails,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: Color(0xFFE2E8F0)),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  Widget _buildDialogRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Color(0xFF64748B))),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 12, color: Color(0xFF0F172A), fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  Widget _buildActionBadge(String action) {
    Color bg = const Color(0xFFF1F5F9);
    Color fg = const Color(0xFF475569);

    if (action.contains('vulnerable')) {
      bg = const Color(0xFFFEF2F2);
      fg = const Color(0xFFDC2626);
    } else if (action.contains('incident')) {
      bg = const Color(0xFFFFF7ED);
      fg = const Color(0xFFEA580C);
    } else if (action.contains('export') || action.contains('recap')) {
      bg = const Color(0xFFEFF6FF);
      fg = const Color(0xFF2563EB);
    } else if (action.contains('ai')) {
      bg = const Color(0xFFFAF5FF);
      fg = const Color(0xFF9333EA);
    } else if (action.contains('master')) {
      bg = const Color(0xFFF0FDF4);
      fg = const Color(0xFF16A34A);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: fg.withValues(alpha: 0.2)),
      ),
      child: Text(
        action.replaceAll('_', ' ').toUpperCase(),
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: fg),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final auditState = ref.watch(auditProvider);
    final notifier = ref.read(auditProvider.notifier);
    final rtName = authState.selectedRT?.name ?? 'RT 01';

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
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
                      'Audit Log & Rekam Jejak Sistem: $rtName',
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Catatan akses data kerentanan, ekspor rekap, modifikasi data, dan konfigurasi AI (FR-ADM-02).',
                      style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
                const Spacer(),
                IconButton.outlined(
                  tooltip: 'Muat ulang audit log',
                  icon: const Icon(Icons.refresh, size: 20),
                  onPressed: () => notifier.loadAuditLogs(),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Filter Toolbar
            Card(
              color: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    SizedBox(
                      width: 260,
                      height: 38,
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: 'Cari aksi, user, entitas...',
                          prefixIcon: const Icon(Icons.search, size: 18),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          isDense: true,
                        ),
                        onChanged: (val) => notifier.setSearchQuery(val),
                      ),
                    ),
                    const SizedBox(width: 14),
                    DropdownButtonHideUnderline(
                      child: Container(
                        height: 38,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: DropdownButton<String>(
                          value: auditState.actionFilter,
                          items: const [
                            DropdownMenuItem(value: 'all', child: Text('Semua Aksi')),
                            DropdownMenuItem(value: 'access_vulnerable_data', child: Text('Akses Data Rentan')),
                            DropdownMenuItem(value: 'export_recap', child: Text('Ekspor Rekap (PDF/CSV)')),
                            DropdownMenuItem(value: 'incident', child: Text('Operasi Insiden')),
                            DropdownMenuItem(value: 'ai_settings', child: Text('Pengaturan AI')),
                            DropdownMenuItem(value: 'master_data', child: Text('Modifikasi Data Master')),
                          ],
                          onChanged: (val) {
                            if (val != null) notifier.setActionFilter(val);
                          },
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'Menampilkan ${auditState.filteredLogs.length} dari ${auditState.total} aktivitas tercatat',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Audit Table Card
            Expanded(
              child: Card(
                color: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                child: auditState.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : auditState.filteredLogs.isEmpty
                        ? const Center(
                            child: Text(
                              'Tidak ada audit log yang sesuai filter.',
                              style: TextStyle(color: Color(0xFF64748B)),
                            ),
                          )
                        : ListView(
                            children: [
                              DataTable(
                                headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                                columns: const [
                                  DataColumn(label: Text('Waktu (WIB)', style: TextStyle(fontWeight: FontWeight.bold))),
                                  DataColumn(label: Text('User ID / Pelaku', style: TextStyle(fontWeight: FontWeight.bold))),
                                  DataColumn(label: Text('Aksi', style: TextStyle(fontWeight: FontWeight.bold))),
                                  DataColumn(label: Text('Entitas', style: TextStyle(fontWeight: FontWeight.bold))),
                                  DataColumn(label: Text('IP Address', style: TextStyle(fontWeight: FontWeight.bold))),
                                  DataColumn(label: Text('Detail', style: TextStyle(fontWeight: FontWeight.bold))),
                                  DataColumn(label: Text('Aksi', style: TextStyle(fontWeight: FontWeight.bold))),
                                ],
                                rows: auditState.filteredLogs.map((log) {
                                  final timeStr =
                                      '${log.createdAt.hour.toString().padLeft(2, '0')}:${log.createdAt.minute.toString().padLeft(2, '0')}:${log.createdAt.second.toString().padLeft(2, '0')}';
                                  final dateStr =
                                      '${log.createdAt.year}-${log.createdAt.month.toString().padLeft(2, '0')}-${log.createdAt.day.toString().padLeft(2, '0')}';

                                  return DataRow(
                                    cells: [
                                      DataCell(
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Text(timeStr, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                            Text(dateStr, style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                                          ],
                                        ),
                                      ),
                                      DataCell(Text(log.userId, style: const TextStyle(fontWeight: FontWeight.w600))),
                                      DataCell(_buildActionBadge(log.action)),
                                      DataCell(Text('${log.entity}: ${log.entityId}', style: const TextStyle(fontSize: 12))),
                                      DataCell(Text(log.ipAddress, style: const TextStyle(fontSize: 12, color: Color(0xFF475569)))),
                                      DataCell(
                                        SizedBox(
                                          width: 200,
                                          child: Text(
                                            log.details.toString(),
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                          ),
                                        ),
                                      ),
                                      DataCell(
                                        IconButton(
                                          tooltip: 'Lihat detail JSON',
                                          icon: const Icon(Icons.info_outline, size: 18, color: Color(0xFF1E3A8A)),
                                          onPressed: () => _showDetailDialog(context, log),
                                        ),
                                      ),
                                    ],
                                  );
                                }).toList(),
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
}
