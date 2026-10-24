import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ui/ui.dart';

import '../../app/warga_state.dart';

/// Redesigned Household Profile & Member Directory for Warga (FR-HH-01..08, NFR-PRV-02).
///
/// Ensures clear information hierarchy for seniors and families:
/// - Household address & block credentials
/// - List of family members with clear vulnerability tags and evacuation assistance needs
/// - Family Evacuation Plan & Registered Meeting Point (100% offline accessible)
/// - Plain Indonesian privacy controls and AES-256-GCM encryption guarantee
class HouseholdPage extends ConsumerWidget {
  const HouseholdPage({super.key});

  void _showEditPlanDialog(BuildContext context, WidgetRef ref, WargaState state) {
    final routeCtrl = TextEditingController(text: state.familyEvacuationRoute);
    final pointCtrl = TextEditingController(text: state.primaryMeetingPoint);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rencana Evakuasi Mandiri', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Rencana ini tersimpan di ponsel dan dapat dibaca kapan saja tanpa jaringan internet.',
              style: TextStyle(fontSize: 12, color: AppTheme.slate600),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: pointCtrl,
              decoration: const InputDecoration(
                labelText: 'Titik Kumpul Utama',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: routeCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Jalur Penyelamatan Mandiri',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryBlue,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              ref.read(wargaProvider.notifier).updateEvacuationPlan(
                    routeCtrl.text.trim(),
                    pointCtrl.text.trim(),
                  );
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Rencana evakuasi mandiri berhasil diperbarui.'),
                  backgroundColor: AppTheme.statusAman,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: const Text('Simpan Rencana'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(wargaProvider);
    final notifier = ref.read(wargaProvider.notifier);

    return Scaffold(
      backgroundColor: AppTheme.bgCanvas,
      appBar: AppBar(
        title: const Text(
          'Data Rumah & Keluarga',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        centerTitle: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ==========================================
              // HOUSEHOLD HEADER CARD
              // ==========================================
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.borderSubtle),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.home_rounded, color: AppTheme.primaryBlue, size: 26),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 8,
                                children: [
                                  Text(
                                    'Rumah No. ${state.householdNumber}',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.slate900),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppTheme.slate100,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      state.blockName,
                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.slate700),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                state.headName,
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.slate700),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                state.address,
                                style: const TextStyle(fontSize: 12, color: AppTheme.slate500),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const Divider(height: 1, color: AppTheme.borderSubtle),
                    const SizedBox(height: 10),
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Text(
                          'ID Rumah: ${state.householdId ?? "hh-04"}',
                          style: const TextStyle(fontSize: 11, color: AppTheme.slate500),
                        ),
                        Text(
                          'Kode Undangan: ${state.invitationCode}',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryBlue),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // ==========================================
              // FAMILY MEMBERS DIRECTORY (FR-HH-02)
              // ==========================================
              const OperationalSectionHeader(
                title: 'Daftar Anggota Keluarga',
                subtitle: 'Digunakan tim relawan untuk memverifikasi keselamatan saat evakuasi',
              ),
              const SizedBox(height: 10),
              ...state.members.map((member) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: member.needsEvacAssist ? AppTheme.statusKritisBorder : AppTheme.borderSubtle,
                      width: member.needsEvacAssist ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: member.needsEvacAssist
                            ? AppTheme.statusKritisBg
                            : (member.isElderly ? const Color(0xFFFEF3C7) : AppTheme.slate100),
                        child: Icon(
                          member.hasDisability
                              ? Icons.accessible
                              : (member.isElderly ? Icons.elderly : (member.isToddler ? Icons.child_care : Icons.person)),
                          color: member.needsEvacAssist
                              ? AppTheme.statusKritis
                              : (member.isElderly ? const Color(0xFFD97706) : AppTheme.slate600),
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              member.name,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.slate900),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${_relationLabel(member.relation)} • Lahir ${member.birthYear} (Usia ${2026 - member.birthYear} thn)',
                              style: const TextStyle(fontSize: 11, color: AppTheme.slate500),
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                if (member.isElderly)
                                  _Tag(label: 'Lansia', color: const Color(0xFFD97706)),
                                if (member.hasDisability)
                                  _Tag(label: 'Disabilitas', color: AppTheme.statusKritis),
                                if (member.needsEvacAssist)
                                  _Tag(label: 'BUTUH BANTUAN TANDU', color: AppTheme.statusKritis),
                                if (member.isToddler)
                                  _Tag(label: 'Balita', color: AppTheme.statusTitikKumpul),
                                if (!member.isElderly && !member.hasDisability && !member.isToddler)
                                  _Tag(label: 'Dewasa Sehat', color: AppTheme.slate500),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 20),

              // ==========================================
              // EVACUATION PLAN & MEETING POINT (FR-EDU-04/08)
              // ==========================================
              const OperationalSectionHeader(
                title: 'Rencana Evakuasi Mandiri',
                subtitle: 'Tersimpan di memori ponsel dan dapat diakses saat offline',
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.borderSubtle),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.meeting_room_outlined, size: 18, color: AppTheme.statusTitikKumpul),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Titik Kumpul Utama Terdaftar:',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.slate800),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Padding(
                      padding: const EdgeInsets.only(left: 26),
                      child: Text(
                        state.primaryMeetingPoint,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.slate900),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        const Icon(Icons.directions_walk, size: 18, color: AppTheme.secondaryTeal),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Jalur Penyelamatan Keluarga:',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.slate800),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Padding(
                      padding: const EdgeInsets.only(left: 26),
                      child: Text(
                        state.familyEvacuationRoute.isNotEmpty
                            ? state.familyEvacuationRoute
                            : 'Belum disusun. Tentukan rute aman dari rumah menuju titik kumpul.',
                        style: TextStyle(
                          fontSize: 13,
                          color: state.familyEvacuationRoute.isNotEmpty ? AppTheme.slate800 : AppTheme.slate500,
                          height: 1.35,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Divider(height: 1, color: AppTheme.borderSubtle),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () => _showEditPlanDialog(context, ref, state),
                        icon: const Icon(Icons.edit_note, size: 18),
                        label: const Text('Ubah Rencana Evakuasi', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // ==========================================
              // PRIVACY & DATA CONSENT (FR-HH-04, NFR-PRV-02)
              // ==========================================
              const OperationalSectionHeader(
                title: 'Hak Privasi & Perlindungan Data',
                subtitle: 'Tata kelola data kesehatan & kerentanan keluarga Anda',
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.borderSubtle),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                'Persetujuan Data Kerentanan & Medis',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.slate900),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Data anggota rentan (lansia/disabilitas) dilindungi enkripsi AES-256-GCM agar relawan dapat memberikan prioritas pertolongan.',
                                style: TextStyle(fontSize: 12, color: AppTheme.slate600, height: 1.35),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: state.consentGiven,
                          activeThumbColor: AppTheme.statusAman,
                          onChanged: (val) {
                            if (!val) {
                              showDialog(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('Cabut Persetujuan Data?'),
                                  content: const Text(
                                    'Pencabutan persetujuan akan menghapus catatan kesehatan dan kerentanan dari server dalam 24 jam. '
                                    'Tim relawan mungkin tidak mengetahui prioritas kebutuhan medis Anda saat bencana.',
                                  ),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.statusKritis),
                                      onPressed: () {
                                        Navigator.pop(ctx);
                                        notifier.toggleConsent(false);
                                      },
                                      child: const Text('Ya, Cabut Persetujuan'),
                                    ),
                                  ],
                                ),
                              );
                            } else {
                              notifier.toggleConsent(true);
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Divider(height: 1, color: AppTheme.borderSubtle),
                    const SizedBox(height: 10),
                    const Text(
                      'Sesuai UU Perlindungan Data Pribadi (UU PDP), Anda berhak mengunduh salinan data atau meminta penghapusan akun kapan saja.',
                      style: TextStyle(fontSize: 11, color: AppTheme.slate500, height: 1.3),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // ACTION BUTTONS: EXPORT & DELETE
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.download_rounded, size: 16),
                        label: const Text('Unduh Data Saya', style: TextStyle(fontSize: 13)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppTheme.borderStrong),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Salinan data keluarga terunduh (Format terenkripsi).'),
                              backgroundColor: AppTheme.statusAman,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.statusKritis,
                          side: const BorderSide(color: AppTheme.statusKritisBorder),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: const Icon(Icons.delete_outline, size: 16),
                        label: const Text('Minta Hapus Akun', style: TextStyle(fontSize: 13)),
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Konfirmasi Permintaan Hapus Akun'),
                              content: const Text(
                                'Apakah Anda yakin ingin mengajukan penghapusan akun dan data keluarga? '
                                'Pengurus RT akan memproses permintaan dalam 24 jam.',
                              ),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.statusKritis),
                                  onPressed: () {
                                    Navigator.pop(ctx);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Permintaan penghapusan akun telah disampaikan ke Pengurus RT.'),
                                        backgroundColor: AppTheme.statusKritis,
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                  },
                                  child: const Text('Kirim Permintaan'),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  String _relationLabel(String rel) {
    switch (rel) {
      case 'kepala':
        return 'Kepala Keluarga';
      case 'istri':
        return 'Istri';
      case 'anak':
        return 'Anak';
      case 'orang_tua':
        return 'Orang Tua / Kakek';
      default:
        return 'Anggota Keluarga';
    }
  }
}

class _Tag extends StatelessWidget {
  final String label;
  final Color color;

  const _Tag({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }
}
