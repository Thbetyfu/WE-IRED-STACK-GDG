import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core/core.dart';

import '../../app/auth_provider.dart';
import 'incident_overview_model.dart';

class IncidentOverviewState {
  final bool isLoading;
  final bool isSubmitting;
  final String? errorMessage;
  final String? successMessage;

  // Active Incident Data
  final Incident? activeIncident;
  final IncidentStatusSummary summary;
  final String durationString;

  // Two-step activation draft
  final DraftActivationResult? draftActivation;

  // BMKG Alert Data
  final BmkgAlert? bmkgAlert;
  final String? bmkgBlockerNote;

  const IncidentOverviewState({
    this.isLoading = false,
    this.isSubmitting = false,
    this.errorMessage,
    this.successMessage,
    this.activeIncident,
    this.summary = const IncidentStatusSummary(),
    this.durationString = 'Tidak Aktif',
    this.draftActivation,
    this.bmkgAlert,
    this.bmkgBlockerNote,
  });

  bool get hasActiveIncident => activeIncident != null && activeIncident!.status == IncidentStatus.aktif;

  IncidentOverviewState copyWith({
    bool? isLoading,
    bool? isSubmitting,
    String? errorMessage,
    String? successMessage,
    Incident? activeIncident,
    bool clearActiveIncident = false,
    IncidentStatusSummary? summary,
    String? durationString,
    DraftActivationResult? draftActivation,
    bool clearDraftActivation = false,
    BmkgAlert? bmkgAlert,
    String? bmkgBlockerNote,
  }) {
    return IncidentOverviewState(
      isLoading: isLoading ?? this.isLoading,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: errorMessage,
      successMessage: successMessage,
      activeIncident: clearActiveIncident ? null : (activeIncident ?? this.activeIncident),
      summary: summary ?? this.summary,
      durationString: durationString ?? this.durationString,
      draftActivation: clearDraftActivation ? null : (draftActivation ?? this.draftActivation),
      bmkgAlert: bmkgAlert ?? this.bmkgAlert,
      bmkgBlockerNote: bmkgBlockerNote ?? this.bmkgBlockerNote,
    );
  }
}

class IncidentOverviewNotifier extends StateNotifier<IncidentOverviewState> {
  final ApiClient? apiClient;
  Timer? _durationTimer;

  IncidentOverviewNotifier({this.apiClient}) : super(const IncidentOverviewState()) {
    _startDurationTimer();
  }

  @override
  void dispose() {
    _durationTimer?.cancel();
    super.dispose();
  }

  void _startDurationTimer() {
    _durationTimer?.cancel();
    _durationTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _updateDuration();
    });
  }

  void _updateDuration() {
    if (state.activeIncident == null || state.activeIncident!.status != IncidentStatus.aktif) {
      if (state.durationString != 'Tidak Aktif') {
        state = state.copyWith(durationString: 'Tidak Aktif');
      }
      return;
    }

    final diff = DateTime.now().difference(state.activeIncident!.startedAt);
    final hours = diff.inHours;
    final mins = diff.inMinutes.remainder(60);

    String text;
    if (hours > 0) {
      text = '$hours jam $mins menit';
    } else {
      text = '$mins menit';
    }

    state = state.copyWith(durationString: text);
  }

  /// Load active incident and status summary (FR-DSH-01, FR-INC-01).
  Future<void> loadIncidentData(String rtId) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    if (apiClient == null) {
      _loadBaselineData(rtId);
      return;
    }

    try {
      // 1. Fetch active incident
      final incResp = await apiClient!.get('/rts/$rtId/incidents/active');
      Incident? inc;
      if (incResp.data['data'] != null) {
        inc = Incident.fromJson(incResp.data['data'] as Map<String, dynamic>);
      }

      // 2. Fetch summary if active incident exists
      IncidentStatusSummary summary = const IncidentStatusSummary();
      if (inc != null) {
        final sumResp = await apiClient!.get('/incidents/${inc.id}/summary');
        if (sumResp.data['data'] != null) {
          summary = IncidentStatusSummary.fromJson(sumResp.data['data'] as Map<String, dynamic>);
        }
      }

      // 3. BMKG Alert check
      final bmkgAlert = BmkgAlert(
        id: 'bmkg-001',
        title: 'Peringatan Dini BMKG: Cuaca Ekstrem Hujan Lebat',
        description: 'Potensi luapan air di bantaran kali dan dataran rendah. Waspada peningkatan debit air.',
        hazard: 'banjir',
        severity: 'warning',
        issuedAt: DateTime.now().subtract(const Duration(minutes: 40)),
        isContractMock: true,
      );

      state = state.copyWith(
        isLoading: false,
        activeIncident: inc,
        clearActiveIncident: inc == null,
        summary: summary,
        bmkgAlert: bmkgAlert,
        bmkgBlockerNote: 'Integrasi live BMKG backend Joshua (J-24) dalam finalisasi; menampilkan kontrak standar.',
      );
      _updateDuration();
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Gagal memuat status insiden: ${e.toString()}',
      );
    }
  }

  /// Step 1: Draft incident activation (FR-INC-01).
  Future<DraftActivationResult?> draftActivation({
    required String rtId,
    required HazardType hazard,
    required IncidentMode mode,
    required List<String> scopeBlockIds,
    required String message,
  }) async {
    state = state.copyWith(isSubmitting: true, errorMessage: null, successMessage: null);

    if (apiClient == null) {
      final draft = DraftActivationResult(
        token: 'draft-token-${DateTime.now().millisecondsSinceEpoch}',
        shortId: mode == IncidentMode.nyata ? 505 : 44001,
        hazard: hazard,
        mode: mode,
        scopeBlockIds: scopeBlockIds,
        message: message,
        expiresAt: DateTime.now().add(const Duration(minutes: 5)),
      );

      state = state.copyWith(isSubmitting: false, draftActivation: draft);
      return draft;
    }

    try {
      final resp = await apiClient!.post('/rts/$rtId/incidents/draft', data: {
        'hazard': hazard.name,
        'mode': mode.name,
        'scope_block_ids': scopeBlockIds,
        'message': message,
      });

      final draft = DraftActivationResult.fromJson(resp.data['data'] as Map<String, dynamic>);
      state = state.copyWith(isSubmitting: false, draftActivation: draft);
      return draft;
    } catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: 'Gagal membuat draf aktivasi: ${e.toString()}',
      );
      return null;
    }
  }

  /// Step 2: Final confirmation of incident activation (FR-INC-01).
  Future<bool> confirmActivation(String rtId, String token) async {
    state = state.copyWith(isSubmitting: true, errorMessage: null, successMessage: null);

    if (apiClient == null) {
      final draft = state.draftActivation;
      final now = DateTime.now();

      final newInc = Incident(
        id: 'inc-${now.millisecondsSinceEpoch}',
        rtId: rtId,
        shortId: draft?.shortId ?? 505,
        hazard: draft?.hazard ?? HazardType.banjir,
        mode: draft?.mode ?? IncidentMode.nyata,
        scopeBlockIds: draft?.scopeBlockIds ?? ['A', 'B'],
        message: draft?.message ?? 'Aktivasi Darurat Siaga Bencana',
        startedBy: 'Pengurus RT',
        startedAt: now,
        status: IncidentStatus.aktif,
      );

      state = state.copyWith(
        isSubmitting: false,
        activeIncident: newInc,
        clearDraftActivation: true,
        summary: const IncidentStatusSummary(
          totalHouseholds: 42,
          aman: 0,
          titikKumpul: 0,
          butuhBantuan: 0,
          kritis: 0,
          belumMelapor: 42,
        ),
        successMessage: 'Insiden ${newInc.mode.name.toUpperCase()} berhasil diaktifkan secara resmi',
      );
      _updateDuration();
      return true;
    }

    try {
      final resp = await apiClient!.post('/rts/$rtId/incidents/confirm', data: {
        'token': token,
      });

      final inc = Incident.fromJson(resp.data['data'] as Map<String, dynamic>);
      state = state.copyWith(
        isSubmitting: false,
        activeIncident: inc,
        clearDraftActivation: true,
        successMessage: 'Insiden ${inc.mode.name.toUpperCase()} berhasil diaktifkan secara resmi',
      );
      await loadIncidentData(rtId);
      return true;
    } catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: 'Gagal mengonfirmasi aktivasi insiden: ${e.toString()}',
      );
      return false;
    }
  }

  /// End incident operation (FR-INC-03).
  Future<bool> endIncident(String rtId, String incidentId) async {
    state = state.copyWith(isSubmitting: true, errorMessage: null, successMessage: null);

    if (apiClient == null) {
      if (state.activeIncident != null) {
        final ended = Incident(
          id: state.activeIncident!.id,
          rtId: state.activeIncident!.rtId,
          shortId: state.activeIncident!.shortId,
          hazard: state.activeIncident!.hazard,
          mode: state.activeIncident!.mode,
          scopeBlockIds: state.activeIncident!.scopeBlockIds,
          message: state.activeIncident!.message,
          startedBy: state.activeIncident!.startedBy,
          startedAt: state.activeIncident!.startedAt,
          endedAt: DateTime.now(),
          status: IncidentStatus.selesai,
        );
        state = state.copyWith(
          isSubmitting: false,
          activeIncident: ended,
          successMessage: 'Operasi tanggap darurat telah diakhiri. Silakan beralih ke halaman Rekapitulasi.',
        );
        _updateDuration();
        return true;
      }
      state = state.copyWith(isSubmitting: false);
      return false;
    }

    try {
      await apiClient!.post('/incidents/$incidentId/end');
      state = state.copyWith(
        isSubmitting: false,
        successMessage: 'Operasi tanggap darurat telah diakhiri secara resmi',
      );
      await loadIncidentData(rtId);
      return true;
    } catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: 'Gagal mengakhiri insiden: ${e.toString()}',
      );
      return false;
    }
  }

  void _loadBaselineData(String rtId) {
    final now = DateTime.now();
    final started = now.subtract(const Duration(hours: 1, minutes: 25));

    final activeIncident = Incident(
      id: 'inc-demo-01',
      rtId: rtId,
      shortId: 505,
      hazard: HazardType.banjir,
      mode: IncidentMode.nyata,
      scopeBlockIds: ['blk-a', 'blk-b'],
      message: 'Banjir luapan kali setinggi 50 cm. Warga dimohon tetap tenang dan segera melapor.',
      startedBy: 'Ketua RT (Budi)',
      startedAt: started,
      status: IncidentStatus.aktif,
    );

    const summary = IncidentStatusSummary(
      totalHouseholds: 42,
      aman: 24,
      titikKumpul: 10,
      butuhBantuan: 5,
      kritis: 2,
      belumMelapor: 3,
    );

    final bmkgAlert = BmkgAlert(
      id: 'bmkg-001',
      title: 'Peringatan Dini Cuaca BMKG: Potensi Hujan Lebat & Angin Kencang',
      description: 'Prakiraan durasi 2 jam ke depan. Potensi genangan air pada wilayah cekungan RT/RW.',
      hazard: 'banjir',
      severity: 'warning',
      issuedAt: now.subtract(const Duration(minutes: 30)),
      isContractMock: true,
    );

    state = state.copyWith(
      isLoading: false,
      activeIncident: activeIncident,
      summary: summary,
      bmkgAlert: bmkgAlert,
      bmkgBlockerNote: 'Integrasi live BMKG backend Joshua (J-24) dalam finalisasi; menampilkan kontrak siaga standar.',
    );
    _updateDuration();
  }
}

final incidentOverviewProvider = StateNotifierProvider<IncidentOverviewNotifier, IncidentOverviewState>((ref) {
  final authState = ref.watch(authProvider);
  final notifier = IncidentOverviewNotifier(apiClient: authState.apiClient);
  final rtId = authState.selectedRT?.id ?? 'rt-01';
  notifier.loadIncidentData(rtId);
  return notifier;
});
