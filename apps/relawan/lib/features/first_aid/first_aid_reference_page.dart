import 'package:flutter/material.dart';
import 'package:content/content.dart';
import 'package:ui/ui.dart';

class FirstAidReferencePage extends StatelessWidget {
  const FirstAidReferencePage({super.key});

  @override
  Widget build(BuildContext context) {
    final guides = FirstAidRepository.guides;

    return Scaffold(
      backgroundColor: AppTheme.bgCanvas,
      appBar: AppBar(
        title: const Text('Referensi P3K Lapangan (Luring)'),
        centerTitle: false,
      ),
      body: SafeArea(
        child: ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: guides.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (ctx, i) {
            final guide = guides[i];
            final isKritis = guide.urgencyLevel == 'kritis';

            return ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              backgroundColor: Colors.white,
              collapsedBackgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: isKritis ? AppTheme.statusKritisBorder : AppTheme.borderSubtle),
              ),
              collapsedShape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: isKritis ? AppTheme.statusKritisBorder : AppTheme.borderSubtle),
              ),
              leading: Icon(
                isKritis ? Icons.emergency : Icons.medical_services_outlined,
                color: isKritis ? AppTheme.statusKritis : const Color(0xFFD97706),
              ),
              title: Text(
                guide.title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.slate900),
              ),
              subtitle: Text(guide.subtitle, style: const TextStyle(fontSize: 11, color: AppTheme.slate600)),
              children: [
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.statusKritisBg,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppTheme.statusKritisBorder),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Tanda Bahaya:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppTheme.statusKritis)),
                            const SizedBox(height: 4),
                            ...guide.dangerSigns.map((d) => Text('• $d', style: const TextStyle(fontSize: 11, color: Color(0xFF7F1D1D)))),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text('Langkah Taktis Penanganan:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      const SizedBox(height: 6),
                      ...guide.steps.map((s) => Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${s.stepNumber}. ', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                                Expanded(
                                  child: Text('${s.title}: ${s.instruction}', style: const TextStyle(fontSize: 11, color: AppTheme.slate800)),
                                ),
                              ],
                            ),
                          )),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
