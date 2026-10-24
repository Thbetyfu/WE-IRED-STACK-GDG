import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core/core.dart';

import '../../app/auth_provider.dart';
import 'recap_model.dart';

class RecapState {
  final bool isLoading;
  final bool isSavingNotes;
  final bool isDraftingAI;
  final bool isApproving;
  final bool isExporting;
  final bool isSendingWA;
  final String? errorMessage;
  final String? successMessage;
  final RecapModel? recap;
  final String? activeIncidentId;

  const RecapState({
    this.isLoading = false,
    this.isSavingNotes = false,
    this.isDraftingAI = false,
    this.isApproving = false,
    this.isExporting = false,
    this.isSendingWA = false,
    this.errorMessage,
    this.successMessage,
    this.recap,
    this.activeIncidentId,
  });

  bool get isEmpty => !isLoading && recap == null;

  RecapState copyWith({
    bool? isLoading,
    bool? isSavingNotes,
    bool? isDraftingAI,
    bool? isApproving,
    bool? isExporting,
    bool? isSendingWA,
    String? errorMessage,
    String? successMessage,
    RecapModel? recap,
    String? activeIncidentId,
  }) {
    return RecapState(
      isLoading: isLoading ?? this.isLoading,
      isSavingNotes: isSavingNotes ?? this.isSavingNotes,
      isDraftingAI: isDraftingAI ?? this.isDraftingAI,
      isApproving: isApproving ?? this.isApproving,
      isExporting: isExporting ?? this.isExporting,
      isSendingWA: isSendingWA ?? this.isSendingWA,
      errorMessage: errorMessage,
      successMessage: successMessage,
      recap: recap ?? this.recap,
      activeIncidentId: activeIncidentId ?? this.activeIncidentId,
    );
  }
}

class RecapNotifier extends StateNotifier<RecapState> {
  final ApiClient? apiClient;

  RecapNotifier({this.apiClient}) : super(const RecapState());

  void clearMessages() {
    state = state.copyWith(errorMessage: null, successMessage: null);
  }

  /// Load recap for a specific incident.
  Future<void> loadRecap(String incidentId) async {
    state = state.copyWith(isLoading: true, errorMessage: null, activeIncidentId: incidentId);

    if (apiClient == null) {
      _loadBaselineData(incidentId);
      return;
    }

    try {
      final resp = await apiClient!.get('/incidents/$incidentId/recap');
      final data = resp.data['data'] as Map<String, dynamic>;
      final recap = RecapModel.fromJson(data);
      state = state.copyWith(
        isLoading: false,
        recap: recap,
      );
    } catch (e) {
      // If recap does not exist yet on server, try to compile it first
      try {
        final compileResp = await apiClient!.post('/incidents/$incidentId/recap');
        final data = compileResp.data['data'] as Map<String, dynamic>;
        final recap = RecapModel.fromJson(data);
        state = state.copyWith(
          isLoading: false,
          recap: recap,
        );
      } catch (compileErr) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'Gagal memuat rekap insiden: ${e.toString()}',
        );
      }
    }
  }

  /// Update recap notes and narrative (FR-RCP-02).
  Future<bool> updateNotes(String recapId, {String? notes, String? narrative}) async {
    state = state.copyWith(isSavingNotes: true, errorMessage: null, successMessage: null);

    if (apiClient == null) {
      if (state.recap != null) {
        final updated = state.recap!.copyWith(
          notes: notes ?? state.recap!.notes,
          narrative: narrative ?? state.recap!.narrative,
          updatedAt: DateTime.now(),
        );
        state = state.copyWith(isSavingNotes: false, recap: updated, successMessage: 'Catatan pengurus berhasil disimpan');
        return true;
      }
      state = state.copyWith(isSavingNotes: false);
      return false;
    }

    try {
      final body = <String, dynamic>{};
      if (notes != null) body['notes'] = notes;
      if (narrative != null) body['narrative'] = narrative;

      final resp = await apiClient!.patch('/recaps/$recapId', data: body);
      final data = resp.data['data'] as Map<String, dynamic>;
      final updated = RecapModel.fromJson(data);

      state = state.copyWith(
        isSavingNotes: false,
        recap: updated,
        successMessage: 'Catatan pengurus berhasil diperbarui',
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isSavingNotes: false,
        errorMessage: 'Gagal menyimpan catatan: ${e.toString()}',
      );
      return false;
    }
  }

  /// Request AI-drafted narrative (FR-AI-03 & SDD 9.5).
  Future<bool> draftAINarrative(String recapId) async {
    state = state.copyWith(isDraftingAI: true, errorMessage: null, successMessage: null);

    if (apiClient == null) {
      if (state.recap != null && state.recap!.data != null) {
        final d = state.recap!.data!;
        final aiText = 'Ringkasan Tanggap Bencana ${d.incident.hazard.toUpperCase()} di ${d.region.rtName} (${d.region.kelurahanName}). '
            'Operasi berjalan selama ${d.incident.duration}. Dari total ${d.householdSummary.total} KK terdaftar, '
            'sebanyak ${d.householdSummary.aman} KK berstatus aman mandiri, ${d.householdSummary.titikKumpul} KK di posko titik kumpul, '
            'dan ${d.householdSummary.butuhBantuan} KK menerima bantuan darurat. Intervensi kebutuhan mencakup ${d.needsSummary.evakuasi} evakuasi '
            'dan ${d.needsSummary.medis} P3K/medis. Jangkauan warga rentan mencapai ${d.vulnerableSummary.percentage.toStringAsFixed(1)}% '
            'dari ${d.vulnerableSummary.totalVulnerable} warga rentan.';
        final updated = state.recap!.copyWith(
          narrative: aiText,
          aiAssisted: true,
          updatedAt: DateTime.now(),
        );
        state = state.copyWith(
          isDraftingAI: false,
          recap: updated,
          successMessage: 'Draf narasi AI berhasil dibuat (periksa dan verifikasi fakta sebelum disetujui)',
        );
        return true;
      }
      state = state.copyWith(isDraftingAI: false);
      return false;
    }

    try {
      final resp = await apiClient!.post('/ai/draft-recap', data: {'recap_id': recapId});
      final data = resp.data['data'] as Map<String, dynamic>;
      final draftText = data['draft_narrative'] as String;

      if (state.recap != null) {
        final updated = state.recap!.copyWith(
          narrative: draftText,
          aiAssisted: true,
          updatedAt: DateTime.now(),
        );
        state = state.copyWith(
          isDraftingAI: false,
          recap: updated,
          successMessage: 'Draf narasi AI berhasil dibuat (periksa dan verifikasi fakta sebelum disetujui)',
        );
        return true;
      }
      state = state.copyWith(isDraftingAI: false);
      return true;
    } catch (e) {
      state = state.copyWith(
        isDraftingAI: false,
        errorMessage: 'Gagal membuat draf narasi AI: ${e.toString()}',
      );
      return false;
    }
  }

  /// Approve recap officially by Pengurus RT (FR-RCP-02).
  Future<bool> approveRecap(String recapId) async {
    state = state.copyWith(isApproving: true, errorMessage: null, successMessage: null);

    if (apiClient == null) {
      if (state.recap != null) {
        final now = DateTime.now();
        final updated = state.recap!.copyWith(
          approvedBy: 'Ketua RT (Simulasi Offline)',
          approvedAt: now,
          updatedAt: now,
        );
        state = state.copyWith(
          isApproving: false,
          recap: updated,
          successMessage: 'Laporan rekap resmi berhasil disetujui oleh Pengurus RT',
        );
        return true;
      }
      state = state.copyWith(isApproving: false);
      return false;
    }

    try {
      final resp = await apiClient!.post('/recaps/$recapId/approve');
      final data = resp.data['data'] as Map<String, dynamic>;
      final updated = RecapModel.fromJson(data);

      state = state.copyWith(
        isApproving: false,
        recap: updated,
        successMessage: 'Laporan rekap resmi berhasil disetujui oleh Pengurus RT',
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isApproving: false,
        errorMessage: 'Gagal menyetujui rekap: ${e.toString()}',
      );
      return false;
    }
  }

  /// Export PDF document (FR-RCP-02 & N-19).
  Future<bool> exportPDF(String recapId) async {
    state = state.copyWith(isExporting: true, errorMessage: null, successMessage: null);

    if (apiClient == null) {
      await Future.delayed(const Duration(milliseconds: 400));
      state = state.copyWith(
        isExporting: false,
        successMessage: 'Dokumen PDF rekap insiden siap diunduh (Simulasi)',
      );
      return true;
    }

    try {
      // Trigger download from backend
      await apiClient!.get('/recaps/$recapId.pdf');
      state = state.copyWith(
        isExporting: false,
        successMessage: 'Dokumen PDF rekap insiden berhasil dibuat dan diunduh',
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isExporting: false,
        errorMessage: 'Gagal mengunduh dokumen PDF: ${e.toString()}',
      );
      return false;
    }
  }

  /// Export CSV table (FR-RCP-02 & N-19).
  Future<bool> exportCSV(String recapId) async {
    state = state.copyWith(isExporting: true, errorMessage: null, successMessage: null);

    if (apiClient == null) {
      await Future.delayed(const Duration(milliseconds: 300));
      state = state.copyWith(
        isExporting: false,
        successMessage: 'Tabel CSV rekap insiden siap diunduh (Simulasi)',
      );
      return true;
    }

    try {
      await apiClient!.get('/recaps/$recapId.csv');
      state = state.copyWith(
        isExporting: false,
        successMessage: 'Tabel CSV rekap insiden berhasil dibuat dan diunduh',
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isExporting: false,
        errorMessage: 'Gagal mengunduh tabel CSV: ${e.toString()}',
      );
      return false;
    }
  }

  /// Send approved recap via WhatsApp Cloud API (FR-RCP-04).
  Future<bool> sendWhatsApp(String recapId, String phone) async {
    if (phone.trim().isEmpty) {
      state = state.copyWith(errorMessage: 'Nomor WhatsApp tujuan wajib diisi');
      return false;
    }

    state = state.copyWith(isSendingWA: true, errorMessage: null, successMessage: null);

    if (apiClient == null) {
      await Future.delayed(const Duration(milliseconds: 500));
      state = state.copyWith(
        isSendingWA: false,
        successMessage: 'Dokumen rekap berhasil dikirimkan via WhatsApp ke $phone (Simulasi)',
      );
      return true;
    }

    try {
      await apiClient!.post('/recaps/$recapId/send-whatsapp', data: {
        'destination_phone': phone.trim(),
      });
      state = state.copyWith(
        isSendingWA: false,
        successMessage: 'Dokumen rekap resmi berhasil dikirim via WhatsApp ke $phone',
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isSendingWA: false,
        errorMessage: 'Gagal mengirim rekap via WhatsApp: ${e.toString()}',
      );
      return false;
    }
  }

  void _loadBaselineData(String incidentId) {
    final now = DateTime.now();
    final started = now.subtract(const Duration(hours: 3));
    final ended = now.subtract(const Duration(minutes: 25));

    final recap = RecapModel(
      id: 'rcp-baseline-001',
      incidentId: incidentId,
      notes: 'Kebutuhan logistik darurat beras dan air bersih telah dikoordinasikan bersama dapur umum RW 05.',
      narrative: 'Insiden Banjir di RT 05 RW 03 Kelurahan Sukamaju berlangsung selama 2 jam 35 menit. '
          'Dari total 42 kepala keluarga terdaftar, sebanyak 28 KK aman mandiri di rumah, 10 KK di balai titik kumpul, '
          'dan 4 KK menerima intervensi bantuan darurat prioritas tinggi.',
      aiAssisted: true,
      approvedBy: null,
      approvedAt: null,
      createdAt: ended,
      updatedAt: ended,
      data: RecapDataModel(
        region: const RegionInfoModel(
          rtId: 'rt-01',
          rtName: 'RT 05',
          rwName: 'RW 03',
          kelurahanName: 'Sukamaju',
          kecamatanName: 'Cilodong',
        ),
        incident: IncidentInfoModel(
          id: incidentId,
          hazard: 'banjir',
          mode: 'nyata',
          status: 'selesai',
          startedAt: started,
          endedAt: ended,
          duration: '2j 35m',
        ),
        householdSummary: const HouseholdSummaryModel(
          total: 42,
          aman: 28,
          titikKumpul: 10,
          butuhBantuan: 4,
          belumMelapor: 0,
        ),
        vulnerableSummary: const VulnerableSummaryModel(
          totalVulnerable: 18,
          reachedCount: 18,
          percentage: 100.0,
        ),
        needsSummary: const NeedsSummaryModel(
          evakuasi: 3,
          medis: 2,
          makananAir: 4,
          tempatTinggal: 1,
          lainnya: 0,
        ),
        followUpHouseholds: const [
          FollowUpHouseholdModel(
            householdId: 'hh-12',
            number: 'B-04',
            headName: 'Siti Aminah',
            address: 'Jl. Mawar No. 4',
            status: 'Butuh Bantuan',
            urgency: 'Kritis',
            needs: ['Evakuasi', 'P3K / Medis'],
            lat: -6.2088,
            lon: 106.8456,
          ),
          FollowUpHouseholdModel(
            householdId: 'hh-18',
            number: 'B-10',
            headName: 'Bambang Sudarsono',
            address: 'Jl. Melati No. 12',
            status: 'Butuh Bantuan',
            urgency: 'Kritis',
            needs: ['Evakuasi', 'Makanan & Air'],
            lat: -6.2091,
            lon: 106.8462,
          ),
          FollowUpHouseholdModel(
            householdId: 'hh-27',
            number: 'C-02',
            headName: 'Endang Rahayu',
            address: 'Jl. Anggrek No. 2',
            status: 'Butuh Bantuan',
            urgency: 'Biasa',
            needs: ['Makanan & Air', 'Hunian Sementara'],
            lat: -6.2075,
            lon: 106.8449,
          ),
        ],
        taskSummary: const TaskSummaryModel(
          total: 8,
          completed: 7,
          inProgress: 1,
          accepted: 0,
          rejected: 0,
          timedOut: 0,
        ),
        metrics: const MetricSummaryModel(
          t90: '18m',
          t100: '32m',
          vulnReached30: 100.0,
          offlineDelivery: 100.0,
          tRecap: '25m',
          byChannel: {
            'aplikasi': 26,
            'whatsapp': 12,
            'relawan': 4,
          },
        ),
        timeline: [
          TimelineEventModel(
            time: started,
            title: 'Aktivasi Tanggap Darurat Siaga Bencana',
            description: 'Ketua RT mengaktifkan mode nyata untuk bencana banjir luapan kali.',
          ),
          TimelineEventModel(
            time: started.add(const Duration(minutes: 18)),
            title: 'Pencapaian Respons T90',
            description: '90% rumah tangga telah terdata status dan kondisinya.',
          ),
          TimelineEventModel(
            time: ended,
            title: 'Penutupan Tanggap Darurat Insiden',
            description: 'Seluruh warga aman dan proses rekapitulasi data dimulai.',
          ),
        ],
      ),
    );

    state = state.copyWith(
      isLoading: false,
      recap: recap,
    );
  }
}

final recapProvider = StateNotifierProvider<RecapNotifier, RecapState>((ref) {
  final authState = ref.watch(authProvider);
  final notifier = RecapNotifier();
  // By default load the latest incident or placeholder
  final activeIncId = 'inc-active-01';
  notifier.loadRecap(activeIncId);
  return notifier;
});
