import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:core/core.dart';
import 'package:ui/ui.dart';

import '../../app/relawan_state.dart';

class ProxyReportPage extends ConsumerStatefulWidget {
  const ProxyReportPage({super.key});

  @override
  ConsumerState<ProxyReportPage> createState() => _ProxyReportPageState();
}

class _ProxyReportPageState extends ConsumerState<ProxyReportPage> {
  String _selectedHouseholdNumber = '07';
  int _selectedStatus = ReportStatus.butuhBantuan;
  int _urgency = ReportUrgency.biasa;
  final Set<String> _needs = {'Makanan / Logistik'};
  final _notesController = TextEditingController();
  int _affectedMembersCount = 1;

  static const List<Map<String, dynamic>> _blockHouseholds = [
    {
      'number': '01',
      'id': 'hh-01',
      'name': 'Keluarga Bpk. Rahmat',
      'address': 'Jl. Merak No. 1',
      'vulnerable': 'Tidak ada',
      'hasVulnerable': false,
      'hasPriorCritical': false,
    },
    {
      'number': '04',
      'id': 'hh-04',
      'name': 'Keluarga Bpk. Santoso',
      'address': 'Jl. Merak No. 4',
      'vulnerable': 'Lansia (78 th) • Balita (2 th)',
      'hasVulnerable': true,
      'hasPriorCritical': true,
    },
    {
      'number': '07',
      'id': 'hh-07',
      'name': 'Keluarga Ibu Maryam',
      'address': 'Jl. Merak No. 7',
      'vulnerable': 'Lansia Hidup Sendiri (Tanpa HP)',
      'hasVulnerable': true,
      'hasPriorCritical': false,
    },
    {
      'number': '09',
      'id': 'hh-09',
      'name': 'Keluarga Bpk. Joko',
      'address': 'Jl. Merak No. 9',
      'vulnerable': 'Tidak ada',
      'hasVulnerable': false,
      'hasPriorCritical': false,
    },
    {
      'number': '11',
      'id': 'hh-11',
      'name': 'Keluarga Bpk. Subandi',
      'address': 'Jl. Merak No. 11',
      'vulnerable': 'Lansia (Perlu Cek Fisik)',
      'hasVulnerable': true,
      'hasPriorCritical': false,
    },
  ];

  Map<String, dynamic> get _currentHousehold {
    return _blockHouseholds.firstWhere(
      (h) => h['number'] == _selectedHouseholdNumber,
      orElse: () => _blockHouseholds.first,
    );
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  void _confirmAndSubmit() {
    final hh = _currentHousehold;
    final isCriticalConflict = hh['hasPriorCritical'] == true && _selectedStatus != ReportStatus.butuhBantuan;

    if (isCriticalConflict) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: AppTheme.statusKritis),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Konfirmasi Resolusi Status',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Text(
            'Rumah No. ${hh['number']} tercatat memiliki laporan Kritis sebelumnya. Sesuai aturan SDD 6.2, perubahan status ke non-kritis membutuhkan konfirmasi bahwa warga telah benar-benar dievakuasi atau aman.',
            style: const TextStyle(fontSize: 12),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal & Periksa Lagi'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                _executeSubmit();
              },
              child: const Text('Ya, Konfirmasi Status'),
            ),
          ],
        ),
      );
    } else {
      _executeSubmit();
    }
  }

  void _executeSubmit() {
    final hh = _currentHousehold;
    ref.read(relawanProvider.notifier).submitProxyReport(
          householdId: 'hh-$_selectedHouseholdNumber',
          householdNumber: _selectedHouseholdNumber,
          headName: hh['name'] as String?,
          address: hh['address'] as String?,
          status: _selectedStatus,
          urgency: _urgency,
          needs: _needs.toList(),
          notes: _notesController.text.trim(),
        );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Laporan proksi Rumah No. $_selectedHouseholdNumber berhasil dicatat ke outbox.'),
        backgroundColor: AppTheme.statusAman,
        behavior: SnackBarBehavior.floating,
      ),
    );

    try {
      if (context.canPop()) {
        context.pop();
      }
    } catch (_) {
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(relawanProvider);
    final isButuhBantuan = _selectedStatus == ReportStatus.butuhBantuan;
    final hh = _currentHousehold;

    return Scaffold(
      backgroundColor: AppTheme.bgCanvas,
      appBar: AppBar(
        title: const Text('Lapor Atas Nama Warga'),
        centerTitle: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Operational Info Banner (FR-PRX-01)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.person_pin, color: Color(0xFFD97706), size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Laporan Proksi Lapangan (FR-PRX-01)',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF92400E)),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Mendata warga tanpa HP, lansia hidup sendiri, atau keluarga dengan baterai HP habis di ${state.assignedBlock}. Laporan akan diteruskan melalui buffer mule dan outbox.',
                            style: const TextStyle(fontSize: 11, color: Color(0xFF78350F), height: 1.3),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // 1. PILIH RUMAH DI BLOK
              const Text(
                '1. Rumah Tangga Sasaran',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.slate900),
              ),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: _selectedHouseholdNumber,
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppTheme.borderSubtle),
                  ),
                ),
                items: _blockHouseholds.map((h) {
                  return DropdownMenuItem<String>(
                    value: h['number'] as String,
                    child: Text(
                      'No. ${h['number']} • ${h['name']}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedHouseholdNumber = val);
                },
              ),
              const SizedBox(height: 8),

              // Household Profile Quick Card
              Container(
                width: double.infinity,
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
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            hh['address'] as String,
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.slate800),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (hh['hasVulnerable'] == true) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF2F2),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: const Color(0xFFFCA5A5)),
                            ),
                            child: const Text(
                              'Kelompok Rentan',
                              style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppTheme.statusKritis),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Rincian Kerentanan: ${hh['vulnerable']}',
                      style: const TextStyle(fontSize: 11, color: AppTheme.slate600),
                    ),
                    if (hh['hasPriorCritical'] == true) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFBEB),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFFCD34D)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.info_outline, size: 14, color: Color(0xFFB45309)),
                            SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Catatan Triase: Rumah ini memiliki laporan awal prioritas tinggi.',
                                style: TextStyle(fontSize: 10, color: Color(0xFF92400E)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // 2. STATUS TEMUAN LAPANGAN
              const Text(
                '2. Status Keselamatan di Lokasi',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.slate900),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _StatusChoiceChip(
                      label: 'Aman di Rumah',
                      sublabel: 'Mandiri / Cukup',
                      isSelected: _selectedStatus == ReportStatus.aman,
                      color: AppTheme.statusAman,
                      icon: Icons.check_circle_outline,
                      onTap: () => setState(() => _selectedStatus = ReportStatus.aman),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _StatusChoiceChip(
                      label: 'Di Titik Kumpul',
                      sublabel: 'Di Balai RW',
                      isSelected: _selectedStatus == ReportStatus.titikKumpul,
                      color: AppTheme.statusTitikKumpul,
                      icon: Icons.flag_outlined,
                      onTap: () => setState(() => _selectedStatus = ReportStatus.titikKumpul),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _StatusChoiceChip(
                      label: 'Butuh Bantuan',
                      sublabel: 'Perlu evakuasi',
                      isSelected: _selectedStatus == ReportStatus.butuhBantuan,
                      color: AppTheme.statusKritis,
                      icon: Icons.emergency_outlined,
                      onTap: () => setState(() => _selectedStatus = ReportStatus.butuhBantuan),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // 3. JIKA BUTUH BANTUAN (URGENSI & KEBUTUHAN)
              if (isButuhBantuan) ...[
                const Text(
                  '3. Tingkat Urgensi & Kebutuhan Spesifik',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.slate900),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _UrgencyChip(
                        label: 'Urgensi Biasa',
                        desc: 'Bantuan logistik / bukan darurat',
                        isSelected: _urgency == ReportUrgency.biasa,
                        color: AppTheme.statusButuhBantuan,
                        onTap: () => setState(() => _urgency = ReportUrgency.biasa),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _UrgencyChip(
                        label: 'Urgensi Kritis',
                        desc: 'Mengancam jiwa / evakuasi medis',
                        isSelected: _urgency == ReportUrgency.kritis,
                        color: AppTheme.statusKritis,
                        onTap: () => setState(() => _urgency = ReportUrgency.kritis),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Pilih Jenis Kebutuhan di Lokasi:',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.slate700),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    'Evakuasi Medis / Tandu',
                    'Makanan / Air Bersih',
                    'Obat-obatan Khusus',
                    'Selimut / Tenda',
                    'Perahu Karet',
                  ].map((item) {
                    final isChecked = _needs.contains(item);
                    return FilterChip(
                      label: Text(item, style: const TextStyle(fontSize: 11)),
                      selected: isChecked,
                      selectedColor: AppTheme.primaryBlue.withValues(alpha: 0.15),
                      checkmarkColor: AppTheme.primaryBlue,
                      onSelected: (val) {
                        setState(() {
                          if (val) {
                            _needs.add(item);
                          } else {
                            _needs.remove(item);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Jumlah Jiwa Terdampak:',
                        style: TextStyle(fontSize: 11, color: AppTheme.slate700),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline, size: 20),
                      onPressed: _affectedMembersCount > 1
                          ? () => setState(() => _affectedMembersCount--)
                          : null,
                    ),
                    Text('$_affectedMembersCount Jiwa', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline, size: 20),
                      onPressed: () => setState(() => _affectedMembersCount++),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],

              // 4. CATATAN RELAWAN
              const Text(
                '4. Catatan Kondisi Lapangan',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.slate900),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _notesController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Contoh: Lansia berada di lantai 2, air masuk 40cm, obat hipertensi tersisa untuk 1 hari.',
                  hintStyle: const TextStyle(fontSize: 11, color: AppTheme.slate400),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppTheme.borderSubtle),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Outbox Reassurance Notice
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.slate100,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    Icon(
                      state.isPoskoConnected ? Icons.cloud_done_outlined : Icons.offline_pin_outlined,
                      size: 16,
                      color: state.isPoskoConnected ? AppTheme.statusAman : AppTheme.slate600,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        state.isPoskoConnected
                            ? 'Posko Lokal Terhubung: Laporan langsung disinkronkan ke server RT.'
                            : 'Mode Offline: Laporan tersimpan di Outbox HP dan akan disinkronkan saat dekat Posko / via BLE.',
                        style: const TextStyle(fontSize: 11, color: AppTheme.slate700),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // SUBMIT BUTTON (Min 52dp touch target)
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.assignment_turned_in),
                  label: const Text(
                    'SIMPAN LAPORAN PROKSI KE OUTBOX',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onPressed: _confirmAndSubmit,
                ),
              ),
              const SizedBox(height: 24),

              // Riwayat Laporan Proksi Sesi Ini
              if (state.proxyReports.isNotEmpty) ...[
                const OperationalSectionHeader(
                  title: 'Riwayat Laporan Proksi Shift Ini',
                  subtitle: 'Tercatat oleh relawan di blok ini',
                ),
                const SizedBox(height: 8),
                ...state.proxyReports.map((p) => _ProxyHistoryCard(report: p)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusChoiceChip extends StatelessWidget {
  final String label;
  final String sublabel;
  final bool isSelected;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;

  const _StatusChoiceChip({
    required this.label,
    required this.sublabel,
    required this.isSelected,
    required this.color,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.12) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? color : AppTheme.borderSubtle,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, size: 20, color: isSelected ? color : AppTheme.slate500),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: isSelected ? color : AppTheme.slate800,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              sublabel,
              style: TextStyle(
                fontSize: 9,
                color: isSelected ? color : AppTheme.slate500,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _UrgencyChip extends StatelessWidget {
  final String label;
  final String desc;
  final bool isSelected;
  final Color color;
  final VoidCallback onTap;

  const _UrgencyChip({
    required this.label,
    required this.desc,
    required this.isSelected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.12) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? color : AppTheme.borderSubtle,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isSelected ? color : AppTheme.slate900,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              desc,
              style: TextStyle(
                fontSize: 10,
                color: isSelected ? color : AppTheme.slate600,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _ProxyHistoryCard extends StatelessWidget {
  final ProxyReportEntry report;

  const _ProxyHistoryCard({required this.report});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
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
            child: const Icon(Icons.receipt_long, color: AppTheme.primaryBlue, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Rumah No. ${report.householdNumber} • ${report.headName}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.slate900),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${report.statusLabel} • ${report.notes.isNotEmpty ? report.notes : "Tanpa catatan"}',
                  style: const TextStyle(fontSize: 10, color: AppTheme.slate600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: report.syncStatus == 'synced' ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              report.syncStatus == 'synced' ? 'Tersinkron' : 'Outbox',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: report.syncStatus == 'synced' ? AppTheme.statusAman : const Color(0xFFB45309),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
