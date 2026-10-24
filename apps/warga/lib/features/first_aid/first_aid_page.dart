import 'package:flutter/material.dart';
import 'package:content/content.dart';
import 'package:go_router/go_router.dart';
import 'package:ui/ui.dart';

class FirstAidPage extends StatefulWidget {
  const FirstAidPage({super.key});

  @override
  State<FirstAidPage> createState() => _FirstAidPageState();
}

class _FirstAidPageState extends State<FirstAidPage> {
  String _searchQuery = '';
  String _selectedCategory = 'Semua';

  static const List<String> _categories = [
    'Semua',
    'Darurat Kritis',
    'Luka & Pendarahan',
    'Patah Tulang',
    'Luka Bakar',
  ];

  @override
  Widget build(BuildContext context) {
    final allGuides = FirstAidRepository.guides;
    final filtered = allGuides.where((g) {
      if (_selectedCategory == 'Darurat Kritis' && g.urgencyLevel != 'kritis') {
        return false;
      }
      if (_selectedCategory == 'Luka & Pendarahan' &&
          !g.title.toLowerCase().contains('darah') &&
          !g.title.toLowerCase().contains('luka')) {
        return false;
      }
      if (_selectedCategory == 'Patah Tulang' && !g.title.toLowerCase().contains('patah') && !g.title.toLowerCase().contains('tulang')) {
        return false;
      }
      if (_selectedCategory == 'Luka Bakar' && !g.title.toLowerCase().contains('bakar')) {
        return false;
      }

      if (_searchQuery.trim().isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return g.title.toLowerCase().contains(q) || g.subtitle.toLowerCase().contains(q);
    }).toList();

    return Scaffold(
      backgroundColor: AppTheme.bgCanvas,
      appBar: AppBar(
        title: const Text('Panduan P3K Darurat', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        centerTitle: false,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Search Bar & Filter Chips
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Column(
                children: [
                  TextField(
                    decoration: InputDecoration(
                      hintText: 'Cari panduan (contoh: CPR, pendarahan, luka bakar)...',
                      prefixIcon: const Icon(Icons.search),
                      fillColor: Colors.white,
                      filled: true,
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () => setState(() => _searchQuery = ''),
                            )
                          : null,
                    ),
                    onChanged: (val) => setState(() => _searchQuery = val),
                  ),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _categories.map((cat) {
                        final isSel = _selectedCategory == cat;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: Text(cat, style: const TextStyle(fontSize: 11)),
                            selected: isSel,
                            onSelected: (_) => setState(() => _selectedCategory = cat),
                            selectedColor: cat == 'Darurat Kritis' ? const Color(0xFFFEE2E2) : AppTheme.primaryBlue.withValues(alpha: 0.15),
                            checkmarkColor: cat == 'Darurat Kritis' ? AppTheme.statusKritis : AppTheme.primaryBlue,
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),

            // Guides List
            Expanded(
              child: filtered.isEmpty
                  ? const EmptyStateView(
                      title: 'Panduan Tidak Ditemukan',
                      description: 'Coba gunakan kata kunci lain seperti luka, patah, pingsan, atau tenggelam.',
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (ctx, i) {
                        final guide = filtered[i];
                        final isKritis = guide.urgencyLevel == 'kritis';

                        return InkWell(
                          onTap: () => _openGuideDetail(context, guide),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isKritis ? AppTheme.statusKritisBorder : AppTheme.borderSubtle,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: isKritis ? AppTheme.statusKritisBg : const Color(0xFFFEF3C7),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    isKritis ? Icons.emergency : Icons.medical_services_outlined,
                                    color: isKritis ? AppTheme.statusKritis : const Color(0xFFD97706),
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              guide.title,
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.slate900),
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: isKritis ? AppTheme.statusKritisBg : const Color(0xFFFEF3C7),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              guide.urgencyLevel.toUpperCase(),
                                              style: TextStyle(
                                                fontSize: 9,
                                                fontWeight: FontWeight.bold,
                                                color: isKritis ? AppTheme.statusKritis : const Color(0xFF92400E),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        guide.subtitle,
                                        style: const TextStyle(fontSize: 11, color: AppTheme.slate600),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Icon(Icons.arrow_forward_ios, size: 14, color: AppTheme.slate400),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _openGuideDetail(BuildContext context, FirstAidGuide guide) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.88,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (ctx, scrollController) {
          final isKritis = guide.urgencyLevel == 'kritis';

          return Container(
            padding: const EdgeInsets.all(20),
            child: ListView(
              controller: scrollController,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            guide.title,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.slate900),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            guide.subtitle,
                            style: const TextStyle(fontSize: 12, color: AppTheme.slate600),
                          ),
                        ],
                      ),
                    ),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 12),

                // TANDA BAHAYA (DANGER SIGNS)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.statusKritisBg,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppTheme.statusKritisBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.warning, size: 16, color: AppTheme.statusKritis),
                          SizedBox(width: 6),
                          Text('Tanda Bahaya Utama:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.statusKritis)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ...guide.dangerSigns.map((sign) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('• ', style: TextStyle(color: AppTheme.statusKritis, fontWeight: FontWeight.bold)),
                                Expanded(child: Text(sign, style: const TextStyle(fontSize: 11, color: Color(0xFF7F1D1D)))),
                              ],
                            ),
                          )),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // LANGKAH TINDAKAN BERNOMOR (FR-FA-02)
                const Text(
                  'Langkah Tindakan Pertolongan Pertama:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.slate900),
                ),
                const SizedBox(height: 8),
                ...guide.steps.map((step) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.slate50,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppTheme.borderSubtle),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: isKritis ? AppTheme.statusKritis : AppTheme.primaryBlue,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              '${step.stepNumber}',
                              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                step.title,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.slate900),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                step.instruction,
                                style: const TextStyle(fontSize: 12, color: AppTheme.slate700, height: 1.35),
                              ),
                              if (step.warning != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  'Perhatian: ${step.warning}',
                                  style: const TextStyle(fontSize: 11, color: Color(0xFFD97706), fontWeight: FontWeight.w600),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 12),

                // HAL YANG HARUS DIHINDARI (THINGS TO AVOID)
                if (guide.thingsToAvoid.isNotEmpty) ...[
                  const Text(
                    'Hal yang Dilarang / Harus Dihindari:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.slate900),
                  ),
                  const SizedBox(height: 6),
                  ...guide.thingsToAvoid.map((avoid) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.cancel_outlined, size: 14, color: AppTheme.statusKritis),
                            const SizedBox(width: 6),
                            Expanded(child: Text(avoid, style: const TextStyle(fontSize: 11, color: AppTheme.slate700))),
                          ],
                        ),
                      )),
                  const SizedBox(height: 16),
                ],

                // ATTRIBUTION & DISCLAIMER
                Text(
                  'Sumber Referensi: ${guide.sourceAttribution}',
                  style: const TextStyle(fontSize: 10, color: AppTheme.slate500, fontStyle: FontStyle.italic),
                ),
                const SizedBox(height: 4),
                Text(
                  guide.medicalDisclaimer,
                  style: const TextStyle(fontSize: 10, color: AppTheme.slate400),
                ),
                const SizedBox(height: 20),

                // QUICK ACTION BUTTON PER FR-FA-03 (>= 64dp, High Contrast)
                SizedBox(
                  width: double.infinity,
                  height: 64,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.statusKritis,
                      foregroundColor: Colors.white,
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.sos, size: 28),
                    label: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'MINTA BANTUAN MEDIS KE RELAWAN',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: -0.2),
                        ),
                        Text(
                          'Kirim formulir darurat medis otomatis ke posko',
                          style: TextStyle(fontSize: 11, color: Colors.white70),
                        ),
                      ],
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      context.push('/report');
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
