import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/auth_provider.dart';

class EducationPage extends ConsumerWidget {
  const EducationPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Admin Edukasi & Skor Kesiapsiagaan: ${authState.selectedRT?.name ?? "RT 01"}',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text(
              'Kelola modul kesiapsiagaan, kuis, evaluasi checklist tas siaga, dan rencana evakuasi mandiri (FR-EDU-06-07).',
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                _EduStatCard(title: 'Rata-rata Skor RT', value: '78.5 / 100', subtitle: '+4.2% bulan ini'),
                const SizedBox(width: 16),
                _EduStatCard(title: 'Warga Menyelesaikan Modul', value: '82%', subtitle: '64 dari 78 rumah'),
                const SizedBox(width: 16),
                _EduStatCard(title: 'Rencana Evakuasi Siap', value: '91%', subtitle: '71 rencana terdaftar'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EduStatCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;

  const _EduStatCard({
    required this.title,
    required this.value,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
            const SizedBox(height: 8),
            Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
            const SizedBox(height: 4),
            Text(subtitle, style: const TextStyle(fontSize: 11, color: Color(0xFF10B981), fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
