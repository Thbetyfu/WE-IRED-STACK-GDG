import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:core/core.dart';
import 'package:ui/ui.dart';

import '../../app/warga_state.dart';
import 'outbox_status_sheet.dart';

/// Redesigned Emergency Help Request Page (FR-RPT-02, FR-RPT-05..06, NFR-USA-01..05)
///
/// Features:
/// - Urgency level selection (Biasa vs Kritis) with high-contrast color scheme
/// - Category of needs multi-selection with inline validation
/// - Affected family members selector reflecting vulnerability flags
/// - 140-character radio packet constraint counter
/// - Accurate delivery mode preview (Cloud vs BLE Relay vs Local Outbox)
/// - Height >= 64dp emergency submit button with critical confirmation dialog
/// - Safe from keyboard overflow on small viewports
class ReportPage extends ConsumerStatefulWidget {
  const ReportPage({super.key});

  @override
  ConsumerState<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends ConsumerState<ReportPage> {
  int _urgency = ReportUrgency.biasa;
  final Set<String> _selectedNeeds = {'Evakuasi', 'Bantuan Medis & Obat'};
  final Set<String> _selectedMemberIds = {'mem-03'};
  final _notesController = TextEditingController();
  bool _showValidationError = false;
  bool _isSubmitting = false;

  static const List<String> _availableNeeds = [
    'Evakuasi / Perahu',
    'Bantuan Medis & Obat',
    'Makanan & Air Bersih',
    'Tempat Pengungsian',
    'Bantuan Khusus Lansia/Disabilitas',
    'Penerangan & Baterai',
  ];

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  void _validateAndSubmit() {
    final hasNeeds = _selectedNeeds.isNotEmpty;
    final hasNotes = _notesController.text.trim().isNotEmpty;

    if (!hasNeeds && !hasNotes) {
      setState(() => _showValidationError = true);
      return;
    }

    setState(() => _showValidationError = false);

    if (_urgency == ReportUrgency.kritis) {
      _showCriticalConfirmationDialog();
    } else {
      _executeSubmit();
    }
  }

  void _showCriticalConfirmationDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppTheme.statusKritis, size: 28),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Konfirmasi Laporan Kritis',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.statusKritis),
              ),
            ),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Laporan dengan urgensi Kritis langsung menaikkan skor triase ke prioritas tertinggi dan membunyikan alarm ke relawan posko.',
              style: TextStyle(fontSize: 13, color: AppTheme.slate800, height: 1.4),
            ),
            SizedBox(height: 10),
            Text(
              'Apakah Anda yakin kondisi keluarga saat ini membutuhkan pertolongan darurat darurat jiwa/medis segera?',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.slate700),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Periksa Kembali', style: TextStyle(color: AppTheme.slate600)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.statusKritis,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _executeSubmit();
            },
            child: const Text('YA, KIRIM SEKARANG', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _executeSubmit() {
    setState(() => _isSubmitting = true);

    ref.read(wargaProvider.notifier).submitHelpReport(
          urgency: _urgency,
          needs: _selectedNeeds.toList(),
          affectedMemberIds: _selectedMemberIds.toList(),
          notes: _notesController.text.trim(),
        );

    setState(() => _isSubmitting = false);

    final state = ref.read(wargaProvider);
    final deliveryMsg = state.latestDeliveryStatus == DeliveryStatus.terkirim
        ? 'Laporan berhasil dikirim ke server Posko & Cloud.'
        : (state.latestDeliveryStatus == DeliveryStatus.diteruskanRelay
            ? 'Laporan disebarkan ke relawan sekitar via Bluetooth Mesh.'
            : 'Laporan disimpan aman di Outbox perangkat (Mode Luring).');

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _urgency == ReportUrgency.kritis
                  ? '🚨 LAPORAN KRITIS BERHASIL DISIARKAN'
                  : 'Laporan Kebutuhan Bantuan Disiarkan',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(deliveryMsg, style: const TextStyle(fontSize: 11)),
          ],
        ),
        backgroundColor: _urgency == ReportUrgency.kritis ? AppTheme.statusKritis : const Color(0xFFD97706),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Lihat Outbox',
          textColor: Colors.white,
          onPressed: () => OutboxStatusSheet.show(context),
        ),
      ),
    );

    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(wargaProvider);
    final isKritis = _urgency == ReportUrgency.kritis;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      backgroundColor: AppTheme.bgCanvas,
      appBar: AppBar(
        title: const Text('Formulir Butuh Bantuan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.outbox_outlined),
            tooltip: 'Status Antrean Outbox',
            onPressed: () => OutboxStatusSheet.show(context),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 14,
            bottom: bottomInset + 32,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ==========================================
              // HOUSEHOLD CREDENTIAL & NETWORK CHANNEL
              // ==========================================
              Container(
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
                      child: const Icon(Icons.home, color: AppTheme.primaryBlue, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Rumah No. ${state.householdNumber} (${state.blockName}) - ${state.headName}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.slate900),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(
                                state.connectionMode == ConnectionMode.online
                                    ? Icons.cloud_done
                                    : (state.connectionMode == ConnectionMode.meshRelay
                                        ? Icons.bluetooth_connected
                                        : Icons.cloud_off),
                                size: 12,
                                color: state.connectionMode == ConnectionMode.online
                                    ? AppTheme.statusAman
                                    : (state.connectionMode == ConnectionMode.meshRelay
                                        ? AppTheme.primaryBlue
                                        : const Color(0xFFD97706)),
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  state.connectionMode == ConnectionMode.online
                                      ? 'Kanal Pengiriman: Langsung ke Posko & Cloud'
                                      : (state.connectionMode == ConnectionMode.meshRelay
                                          ? 'Kanal Pengiriman: BLE Mesh Relay Relawan'
                                          : 'Kanal Pengiriman: Disimpan di Outbox Lokal'),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: state.connectionMode == ConnectionMode.online
                                        ? AppTheme.statusAman
                                        : (state.connectionMode == ConnectionMode.meshRelay
                                            ? AppTheme.primaryBlue
                                            : const Color(0xFFD97706)),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
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
              const SizedBox(height: 18),

              // ==========================================
              // 1. TINGKAT URGENSI (FR-RPT-02)
              // ==========================================
              const Text(
                '1. Tingkat Urgensi Bantuan',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.slate900),
              ),
              const SizedBox(height: 4),
              const Text(
                'Pilih Kritis jika ada bahaya jiwa atau korban butuh penanganan medis darurat.',
                style: TextStyle(fontSize: 11, color: AppTheme.slate500),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _UrgencyCard(
                      title: 'Urgensi Biasa',
                      subtitle: 'Logistik, terisolir, sandang',
                      isSelected: _urgency == ReportUrgency.biasa,
                      color: const Color(0xFFD97706),
                      icon: Icons.info_outline,
                      onTap: () => setState(() => _urgency = ReportUrgency.biasa),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _UrgencyCard(
                      title: 'Urgensi Kritis',
                      subtitle: 'Bahaya jiwa, luka berat, pingsan',
                      isSelected: _urgency == ReportUrgency.kritis,
                      color: AppTheme.statusKritis,
                      icon: Icons.warning_rounded,
                      onTap: () => setState(() => _urgency = ReportUrgency.kritis),
                    ),
                  ),
                ],
              ),
              if (isKritis) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.statusKritisBg,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppTheme.statusKritisBorder),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.warning, size: 16, color: AppTheme.statusKritis),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'PERINGATAN: Laporan Kritis menaikkan prioritas triase dan menyiarkan alarm sirene ke relawan blok.',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.statusKritis),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),

              // ==========================================
              // 2. KEBUTUHAN UTAMA
              // ==========================================
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      '2. Kebutuhan Bantuan Utama',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.slate900),
                    ),
                  ),
                  Text(
                    '(${_selectedNeeds.length} dipilih)',
                    style: const TextStyle(fontSize: 11, color: AppTheme.slate500, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Pilih satu atau beberapa kebutuhan bantuan yang mendesak.',
                style: TextStyle(fontSize: 11, color: AppTheme.slate500),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _availableNeeds.map((need) {
                  final isSelected = _selectedNeeds.contains(need);
                  return FilterChip(
                    label: Text(need, style: const TextStyle(fontSize: 12)),
                    selected: isSelected,
                    onSelected: (val) {
                      setState(() {
                        if (val) {
                          _selectedNeeds.add(need);
                        } else {
                          _selectedNeeds.remove(need);
                        }
                      });
                    },
                    selectedColor: isKritis ? AppTheme.statusKritisBg : const Color(0xFFFEF3C7),
                    checkmarkColor: isKritis ? AppTheme.statusKritis : const Color(0xFF92400E),
                  );
                }).toList(),
              ),

              if (_showValidationError && _selectedNeeds.isEmpty && _notesController.text.trim().isEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFFCA5A5)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.error_outline, size: 14, color: AppTheme.statusKritis),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Pilih minimal 1 kebutuhan bantuan atau tuliskan catatan di bawah.',
                          style: TextStyle(fontSize: 11, color: AppTheme.statusKritis, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),

              // ==========================================
              // 3. ANGGOTA KELUARGA TERDAMPAK
              // ==========================================
              const Text(
                '3. Anggota Keluarga yang Membutuhkan Perhatian Khusus',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.slate900),
              ),
              const SizedBox(height: 4),
              const Text(
                'Centang anggota yang sakit, lansia, balita, atau butuh bantuan evakuasi.',
                style: TextStyle(fontSize: 11, color: AppTheme.slate500),
              ),
              const SizedBox(height: 8),
              Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.borderSubtle),
                  ),
                  child: Column(
                    children: state.members.map((member) {
                      final isSelected = _selectedMemberIds.contains(member.id);
                      return CheckboxListTile(
                        dense: true,
                        value: isSelected,
                        title: Text(
                          member.name,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.slate900),
                        ),
                        subtitle: Text(
                          member.hasDisability
                              ? 'Disabilitas / Tirah Baring (Butuh Bantuan Tandu)'
                              : (member.isElderly ? 'Lansia' : (member.isToddler ? 'Balita' : 'Dewasa Sehat')),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: member.hasDisability || member.isElderly ? FontWeight.bold : FontWeight.normal,
                            color: member.hasDisability || member.isElderly ? AppTheme.statusKritis : AppTheme.slate500,
                          ),
                        ),
                        onChanged: (val) {
                          setState(() {
                            if (val == true) {
                              _selectedMemberIds.add(member.id);
                            } else {
                              _selectedMemberIds.remove(member.id);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // ==========================================
              // 4. PESAN SINGKAT (140 Karakter FR-RPT-02)
              // ==========================================
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Text(
                      '4. Catatan Kondisi untuk Relawan',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.slate900),
                    ),
                  ),
                  Text(
                    '${_notesController.text.length} / 140',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: _notesController.text.length > 140 ? AppTheme.statusKritis : AppTheme.slate500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Maksimal 140 karakter agar muat dalam transmisi paket radio / BLE hemat daya.',
                style: TextStyle(fontSize: 10, color: AppTheme.slate500),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _notesController,
                maxLength: 140,
                maxLines: 3,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  hintText: 'Contoh: Terjebak di lantai 2 air 1 meter, butuh tandu untuk kakek yang sakit.',
                  counterText: '',
                  fillColor: Colors.white,
                  filled: true,
                ),
              ),
              const SizedBox(height: 24),

              // ==========================================
              // 5. EMERGENCY SUBMIT BUTTON (>= 64 DP)
              // ==========================================
              EmergencyActionButton.butuhBantuan(
                isKritis: isKritis,
                isLoading: _isSubmitting,
                onPressed: _validateAndSubmit,
              ),

              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.shield_outlined, size: 14, color: AppTheme.slate500),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      state.connectionMode == ConnectionMode.online
                          ? 'Koneksi Posko aktif. Laporan dikirim seketika.'
                          : (state.connectionMode == ConnectionMode.meshRelay
                              ? 'Bluetooth Mesh siap meneruskan paket.'
                              : 'Mode luring: Paket tersimpan di outbox lokal.'),
                      style: const TextStyle(fontSize: 11, color: AppTheme.slate500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UrgencyCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool isSelected;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;

  const _UrgencyCard({
    required this.title,
    required this.subtitle,
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
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.1) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? color : AppTheme.borderSubtle,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: color),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: isSelected ? color : AppTheme.slate800,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 11, color: AppTheme.slate500),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
