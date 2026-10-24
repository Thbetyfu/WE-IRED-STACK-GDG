import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:content/content.dart';
import 'package:ui/ui.dart';

import '../../app/warga_state.dart';

class EducationPage extends ConsumerStatefulWidget {
  const EducationPage({super.key});

  @override
  ConsumerState<EducationPage> createState() => _EducationPageState();
}

class _EducationPageState extends ConsumerState<EducationPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _routeController = TextEditingController();
  final _meetingPointController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    final state = ref.read(wargaProvider);
    _routeController.text = state.familyEvacuationRoute;
    _meetingPointController.text = state.primaryMeetingPoint;
  }

  @override
  void dispose() {
    _tabController.dispose();
    _routeController.dispose();
    _meetingPointController.dispose();
    super.dispose();
  }

  void _openModuleModal(EducationModule module) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => _ModuleDetailModal(
        module: module,
        onQuizCompleted: (score) {
          ref.read(wargaProvider.notifier).recordQuizScore(module.id, score);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(wargaProvider);
    final notifier = ref.read(wargaProvider.notifier);
    final modules = EducationRepository.modules;
    final bagItems = EducationRepository.defaultBagItems;

    return Scaffold(
      backgroundColor: AppTheme.bgCanvas,
      appBar: AppBar(
        title: const Text('Edukasi Kesiapsiagaan'),
        centerTitle: false,
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primaryBlue,
          unselectedLabelColor: AppTheme.slate500,
          indicatorColor: AppTheme.primaryBlue,
          tabs: const [
            Tab(text: 'Modul & Kuis'),
            Tab(text: 'Tas Siaga 72 Jam'),
            Tab(text: 'Rencana Evakuasi'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // TAB 1: MODUL & KUIS
          ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: modules.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (ctx, i) {
              final mod = modules[i];
              final hasScore = state.quizScores.containsKey(mod.id);
              final score = state.quizScores[mod.id] ?? 0;

              return InkWell(
                onTap: () => _openModuleModal(mod),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.borderSubtle),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.menu_book, color: AppTheme.primaryBlue, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              mod.title,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.slate900),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              mod.summary,
                              style: const TextStyle(fontSize: 11, color: AppTheme.slate600),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Sumber: ${mod.officialSource} • ~${mod.estimatedMinutes} menit',
                              style: const TextStyle(fontSize: 10, color: AppTheme.slate500),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (hasScore)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDCFCE7),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Column(
                            children: [
                              const Icon(Icons.check_circle, size: 14, color: AppTheme.statusAman),
                              Text('$score%', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.statusAman)),
                            ],
                          ),
                        )
                      else
                        const Icon(Icons.arrow_forward_ios, size: 14, color: AppTheme.slate400),
                    ],
                  ),
                ),
              );
            },
          ),

          // TAB 2: TAS SIAGA BENCANA (72-HOUR GRAB BAG)
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.backpack, color: Color(0xFFD97706), size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Tas Siaga Bencana (Survival Kit 72 Jam)',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF92400E)),
                            ),
                            Text(
                              'Siapkan tas darurat di dekat pintu keluar berisi perbekalan minimal 3 hari sebelum bantuan tiba. Kelengkapan: ${state.checkedBagItemIds.length}/${bagItems.length} item.',
                              style: const TextStyle(fontSize: 11, color: Color(0xFF78350F), height: 1.3),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                ...bagItems.map((item) {
                  final isChecked = state.checkedBagItemIds.contains(item.id);
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: isChecked ? AppTheme.statusAmanBorder : AppTheme.borderSubtle),
                    ),
                    child: CheckboxListTile(
                      value: isChecked,
                      activeColor: AppTheme.statusAman,
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.name,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                decoration: isChecked ? TextDecoration.lineThrough : null,
                                color: isChecked ? AppTheme.slate500 : AppTheme.slate900,
                              ),
                            ),
                          ),
                          if (item.isEssential)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEE2E2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text('Wajib', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppTheme.statusKritis)),
                            ),
                        ],
                      ),
                      subtitle: Text(
                        item.description,
                        style: const TextStyle(fontSize: 11, color: AppTheme.slate500),
                      ),
                      onChanged: (_) => notifier.toggleBagItem(item.id),
                    ),
                  );
                }),
              ],
            ),
          ),

          // TAB 3: RENCANA EVAKUASI KELUARGA
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const OperationalSectionHeader(
                  title: 'Rencana Evakuasi Mandiri Rumah Tangga',
                  subtitle: 'Pastikan seluruh anggota keluarga mengetahui jalur keluar dan titik berkumpul',
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _meetingPointController,
                  decoration: const InputDecoration(
                    labelText: 'Titik Kumpul Evakuasi Keluarga',
                    hintText: 'Contoh: Balai Warga RT 05 atau Lapangan RW',
                    prefixIcon: Icon(Icons.flag_outlined),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _routeController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Rute Evakuasi Bebas Hambatan',
                    hintText: 'Contoh: Keluar lewat pintu belakang ke gang barat, hindari tiang listrik dekat gerbang depan.',
                    prefixIcon: Icon(Icons.alt_route),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.save),
                    label: const Text('Simpan Rencana Evakuasi'),
                    onPressed: () {
                      notifier.updateEvacuationPlan(
                        _routeController.text.trim(),
                        _meetingPointController.text.trim(),
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Rencana evakuasi berhasil disimpan secara luring.'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ModuleDetailModal extends StatefulWidget {
  final EducationModule module;
  final ValueChanged<int> onQuizCompleted;

  const _ModuleDetailModal({
    required this.module,
    required this.onQuizCompleted,
  });

  @override
  State<_ModuleDetailModal> createState() => _ModuleDetailModalState();
}

class _ModuleDetailModalState extends State<_ModuleDetailModal> {
  bool _showQuiz = false;
  final Map<String, String> _selectedAnswers = {}; // questionId -> choiceId
  bool _quizSubmitted = false;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      expand: false,
      builder: (ctx, scrollController) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: ListView(
            controller: scrollController,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.module.title,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.slate900),
                    ),
                  ),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Sumber: ${widget.module.officialSource} • Durasi baca: ~${widget.module.estimatedMinutes} menit',
                style: const TextStyle(fontSize: 11, color: AppTheme.slate500),
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 12),

              if (!_showQuiz) ...[
                const Text(
                  'Panduan Taktis Kesiapsiagaan:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.slate900),
                ),
                const SizedBox(height: 10),
                ...widget.module.bulletPoints.asMap().entries.map((entry) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              '${entry.key + 1}',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryBlue),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            entry.value,
                            style: const TextStyle(fontSize: 13, color: AppTheme.slate800, height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.quiz_outlined),
                    label: Text('Mulai Kuis Pemahaman (${widget.module.quiz.length} Soal)'),
                    onPressed: () => setState(() => _showQuiz = true),
                  ),
                ),
              ],

              if (_showQuiz) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Kuis Pemahaman Mandiri', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    TextButton(onPressed: () => setState(() => _showQuiz = false), child: const Text('← Baca Panduan')),
                  ],
                ),
                const SizedBox(height: 8),
                ...widget.module.quiz.asMap().entries.map((qEntry) {
                  final q = qEntry.value;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.slate50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.borderSubtle),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Soal ${qEntry.key + 1}: ${q.question}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.slate900),
                        ),
                        const SizedBox(height: 8),
                        ...q.choices.map((choice) {
                          final isSelected = _selectedAnswers[q.id] == choice.id;
                          Color tileBg = Colors.white;
                          if (_quizSubmitted) {
                            if (choice.isCorrect) {
                              tileBg = const Color(0xFFDCFCE7);
                            } else if (isSelected) {
                              tileBg = const Color(0xFFFEE2E2);
                            }
                          }

                          return Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            decoration: BoxDecoration(
                              color: tileBg,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: isSelected ? AppTheme.primaryBlue : AppTheme.borderSubtle,
                                width: isSelected ? 1.5 : 1.0,
                              ),
                            ),
                            child: InkWell(
                              onTap: _quizSubmitted
                                  ? null
                                  : () {
                                      setState(() {
                                        _selectedAnswers[q.id] = choice.id;
                                      });
                                    },
                              borderRadius: BorderRadius.circular(6),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 18,
                                      height: 18,
                                      margin: const EdgeInsets.only(top: 2),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: isSelected ? AppTheme.primaryBlue : AppTheme.slate400,
                                          width: 2,
                                        ),
                                        color: isSelected ? AppTheme.primaryBlue : Colors.transparent,
                                      ),
                                      child: isSelected
                                          ? const Center(
                                              child: Icon(Icons.circle, size: 8, color: Colors.white),
                                            )
                                          : null,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(choice.text, style: const TextStyle(fontSize: 12, color: AppTheme.slate800)),
                                          if (_quizSubmitted && (choice.isCorrect || isSelected)) ...[
                                            const SizedBox(height: 4),
                                            Text(
                                              choice.explanation,
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: choice.isCorrect ? AppTheme.statusAman : AppTheme.statusKritis,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 16),
                if (!_quizSubmitted)
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _selectedAnswers.length == widget.module.quiz.length
                          ? () {
                              int correct = 0;
                              for (final q in widget.module.quiz) {
                                final selected = _selectedAnswers[q.id];
                                final match = q.choices.firstWhere((c) => c.id == selected);
                                if (match.isCorrect) correct++;
                              }
                              final scorePercent = ((correct / widget.module.quiz.length) * 100).round();
                              widget.onQuizCompleted(scorePercent);
                              setState(() => _quizSubmitted = true);
                            }
                          : null,
                      child: const Text('Kirim Jawaban Kuis'),
                    ),
                  )
                else
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Selesai & Simpan Skor'),
                    ),
                  ),
              ],
            ],
          ),
        );
      },
    );
  }
}
