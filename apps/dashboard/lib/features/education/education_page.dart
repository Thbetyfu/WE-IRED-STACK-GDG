import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:content/content.dart';
import 'package:ui/ui.dart';

import '../../app/auth_provider.dart';

class EducationPage extends ConsumerStatefulWidget {
  const EducationPage({super.key});

  @override
  ConsumerState<EducationPage> createState() => _EducationPageState();
}

class _EducationPageState extends ConsumerState<EducationPage> {
  String _selectedHazard = 'all';

  void _showModulePreview(EducationModule mod) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          children: [
            const Icon(Icons.school, color: AppTheme.primaryBlue),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                mod.title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 540,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.slate100,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.source_outlined, size: 16, color: AppTheme.slate600),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Sumber Resmi: ${mod.officialSource} • Estimasi Baca: ~${mod.estimatedMinutes} menit',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.slate700),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Daftar Soal Kuis Pemahaman Warga:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.slate900),
                ),
                const SizedBox(height: 8),
                ...mod.quiz.asMap().entries.map((entry) {
                  final idx = entry.key + 1;
                  final q = entry.value;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppTheme.borderSubtle),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$idx. ${q.question}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                          const SizedBox(height: 6),
                          ...q.choices.map((choice) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Row(
                                children: [
                                  Icon(
                                    choice.isCorrect ? Icons.check_circle : Icons.radio_button_unchecked,
                                    size: 14,
                                    color: choice.isCorrect ? AppTheme.statusAman : AppTheme.slate400,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      choice.text,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: choice.isCorrect ? FontWeight.bold : FontWeight.normal,
                                        color: choice.isCorrect ? AppTheme.statusAman : AppTheme.slate600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Tutup')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final allModules = EducationRepository.modules;
    final bagItems = EducationRepository.defaultBagItems;

    final modules = allModules.where((m) {
      if (_selectedHazard != 'all' && m.disasterType.toLowerCase() != _selectedHazard.toLowerCase()) {
        return false;
      }
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Page Header
            OperationalPageHeader(
              title: 'Admin Edukasi & Skor Kesiapsiagaan: ${authState.selectedRT?.name ?? "RT 05"}',
              subtitle: 'Modul kesiapsiagaan keluarga (adaptasi NALARIA), kuis pemahaman, dan evaluasi Tas Siaga 72 Jam (FR-EDU-06-07, SDD 6.4).',
              actions: [
                const DemoDataBadge(note: 'SKOR RT: DATA ANALITIK'),
                OutlinedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Mengunduh dokumen rekap kesiapsiagaan blok RT format CSV...'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  icon: const Icon(Icons.download, size: 16),
                  label: const Text('Unduh Rekap CSV', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Metrics Summary
            LayoutBuilder(
              builder: (context, constraints) {
                final totalWidth = constraints.maxWidth;
                final t1 = OperationalMetricTile(
                  label: 'Rata-rata Skor Kesiapsiagaan',
                  value: '78.5 / 100',
                  subtitle: 'Formula SDD 6.4 (Modul + Kuis + Tas Siaga + Rencana)',
                  icon: Icons.speed,
                  accentColor: AppTheme.primaryBlue,
                );
                final t2 = OperationalMetricTile(
                  label: 'Penyelesaian Modul',
                  value: '82%',
                  subtitle: '64 dari 78 Kepala Keluarga',
                  icon: Icons.menu_book,
                  accentColor: AppTheme.secondaryTeal,
                );
                final t3 = OperationalMetricTile(
                  label: 'Tas Siaga Mandiri 72 Jam',
                  value: '74%',
                  subtitle: '58 rumah telah melengkapi checklist',
                  icon: Icons.backpack,
                  accentColor: const Color(0xFFD97706),
                );
                final t4 = OperationalMetricTile(
                  label: 'Rencana Evakuasi Siap',
                  value: '91%',
                  subtitle: '71 titik kumpul keluarga terdaftar',
                  icon: Icons.alt_route,
                  accentColor: AppTheme.statusAman,
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

            // Modules Table & Block Readiness
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 950;

                final modulesList = Container(
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
                            child: OperationalSectionHeader(
                              title: 'Modul Edukasi Kesiapsiagaan Bencana',
                              subtitle: 'Materi edukasi offline tersinkronisasi ke seluruh aplikasi warga',
                            ),
                          ),
                          DropdownButtonHideUnderline(
                            child: Container(
                              height: 32,
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              decoration: BoxDecoration(
                                border: Border.all(color: AppTheme.borderSubtle),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: DropdownButton<String>(
                                value: _selectedHazard,
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.slate800),
                                items: const [
                                  DropdownMenuItem(value: 'all', child: Text('Semua Bahaya')),
                                  DropdownMenuItem(value: 'banjir', child: Text('Banjir')),
                                  DropdownMenuItem(value: 'gempa', child: Text('Gempa Bumi')),
                                  DropdownMenuItem(value: 'kebakaran', child: Text('Kebakaran')),
                                ],
                                onChanged: (v) {
                                  if (v != null) setState(() => _selectedHazard = v);
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (modules.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(
                            child: Text('Tidak ada modul untuk kategori bahaya ini.', style: TextStyle(color: AppTheme.slate500)),
                          ),
                        )
                      else
                        ...modules.map((mod) {
                          return InkWell(
                            onTap: () => _showModulePreview(mod),
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 12),
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
                                      color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Icon(Icons.school, color: AppTheme.primaryBlue, size: 20),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          mod.title,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.slate900),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Sumber: ${mod.officialSource} • Durasi baca: ~${mod.estimatedMinutes} menit • ${mod.quiz.length} Soal Kuis',
                                          style: const TextStyle(fontSize: 11, color: AppTheme.slate500),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFDCFCE7),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text('Terbit (Luring)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.statusAman)),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                    ],
                  ),
                );

                final blockReadiness = Container(
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
                        title: 'Kesiapan Berdasarkan Blok RT',
                        subtitle: 'Persentase kelulusan kuis & kesiapan tas siaga',
                      ),
                      const SizedBox(height: 8),
                      const _BlockProgressRow(blockName: 'Blok A (Jl. Merak)', percentage: 88, completedCount: 22, totalCount: 25),
                      const SizedBox(height: 12),
                      const _BlockProgressRow(blockName: 'Blok B (Jl. Merak Atas)', percentage: 76, completedCount: 19, totalCount: 25),
                      const SizedBox(height: 12),
                      const _BlockProgressRow(blockName: 'Blok C (Jl. Kutilang)', percentage: 71, completedCount: 20, totalCount: 28),
                      const SizedBox(height: 20),
                      const Divider(),
                      const SizedBox(height: 8),
                      const Text(
                        'Item Tas Siaga 72 Jam Wajib:',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.slate800),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: bagItems.where((b) => b.isEssential).map((item) {
                          return Chip(
                            label: Text(item.name, style: const TextStyle(fontSize: 11)),
                            backgroundColor: AppTheme.slate100,
                            padding: EdgeInsets.zero,
                            visualDensity: VisualDensity.compact,
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                );

                if (isWide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 3, child: modulesList),
                      const SizedBox(width: 20),
                      Expanded(flex: 2, child: blockReadiness),
                    ],
                  );
                }

                return Column(
                  children: [
                    modulesList,
                    const SizedBox(height: 20),
                    blockReadiness,
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

class _BlockProgressRow extends StatelessWidget {
  final String blockName;
  final int percentage;
  final int completedCount;
  final int totalCount;

  const _BlockProgressRow({
    required this.blockName,
    required this.percentage,
    required this.completedCount,
    required this.totalCount,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                blockName,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.slate800),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '$percentage% ($completedCount/$totalCount KK)',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryBlue),
            ),
          ],
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: percentage / 100.0,
          backgroundColor: AppTheme.slate200,
          color: percentage >= 80 ? AppTheme.statusAman : (percentage >= 70 ? AppTheme.primaryBlue : const Color(0xFFD97706)),
          minHeight: 6,
          borderRadius: BorderRadius.circular(3),
        ),
      ],
    );
  }
}
