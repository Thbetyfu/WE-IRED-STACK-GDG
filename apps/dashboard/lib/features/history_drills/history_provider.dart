import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core/core.dart';

import '../../app/auth_provider.dart';

class HistoryState {
  final bool isLoading;
  final String? errorMessage;
  final IncidentMode selectedMode;
  final DrillComparisonSummary? drillComparison;
  final List<Incident> realIncidents;
  final List<Incident> drillIncidents;

  const HistoryState({
    this.isLoading = false,
    this.errorMessage,
    this.selectedMode = IncidentMode.latihan,
    this.drillComparison,
    this.realIncidents = const [],
    this.drillIncidents = const [],
  });

  HistoryState copyWith({
    bool? isLoading,
    String? errorMessage,
    IncidentMode? selectedMode,
    DrillComparisonSummary? drillComparison,
    List<Incident>? realIncidents,
    List<Incident>? drillIncidents,
  }) {
    return HistoryState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      selectedMode: selectedMode ?? this.selectedMode,
      drillComparison: drillComparison ?? this.drillComparison,
      realIncidents: realIncidents ?? this.realIncidents,
      drillIncidents: drillIncidents ?? this.drillIncidents,
    );
  }
}

class HistoryNotifier extends StateNotifier<HistoryState> {
  final ApiClient? apiClient;

  HistoryNotifier({this.apiClient}) : super(const HistoryState());

  void setMode(IncidentMode mode) {
    state = state.copyWith(selectedMode: mode);
  }

  Future<void> loadHistory(String rtId) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    if (apiClient == null) {
      // Fallback baseline for standalone UI testing / demo
      _loadBaselineData();
      return;
    }

    try {
      // 1. Fetch Drill Comparison Summary
      final compResp = await apiClient!.get('/rts/$rtId/drills/comparison');
      final compData = compResp.data['data'] as Map<String, dynamic>;
      final summary = DrillComparisonSummary.fromJson(compData);

      // 2. Fetch Drill Incidents (mode=latihan)
      final drillsResp = await apiClient!.get('/rts/$rtId/incidents', queryParameters: {'mode': 'latihan'});
      final drillsList = (drillsResp.data['data'] as List<dynamic>)
          .map((e) => Incident.fromJson(e as Map<String, dynamic>))
          .toList();

      // 3. Fetch Real Incidents (mode=nyata)
      final realsResp = await apiClient!.get('/rts/$rtId/incidents', queryParameters: {'mode': 'nyata'});
      final realsList = (realsResp.data['data'] as List<dynamic>)
          .map((e) => Incident.fromJson(e as Map<String, dynamic>))
          .toList();

      state = state.copyWith(
        isLoading: false,
        drillComparison: summary,
        drillIncidents: drillsList,
        realIncidents: realsList,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Gagal memuat data riwayat dari server: $e',
      );
    }
  }

  void _loadBaselineData() {
    final sampleMetrics = [
      DrillComparisonMetric(
        incidentId: 'drill-001',
        hazard: HazardType.gempa,
        startedAt: DateTime.now().subtract(const Duration(days: 30)),
        t90: 38,
        t100: 55,
        vulnReached30: 65.0,
        offlineDelivery: 45.0,
      ),
      DrillComparisonMetric(
        incidentId: 'drill-002',
        hazard: HazardType.banjir,
        startedAt: DateTime.now().subtract(const Duration(days: 14)),
        t90: 28,
        t100: 42,
        vulnReached30: 78.0,
        offlineDelivery: 60.0,
      ),
      DrillComparisonMetric(
        incidentId: 'drill-003',
        hazard: HazardType.banjir,
        startedAt: DateTime.now().subtract(const Duration(days: 3)),
        t90: 21,
        t100: 32,
        vulnReached30: 89.0,
        offlineDelivery: 74.0,
      ),
    ];

    final summary = DrillComparisonSummary(
      totalDrills: sampleMetrics.length,
      averageVulnReached30: 77.3,
      averageOfflineDelivery: 59.7,
      trend: 'improving',
      drills: sampleMetrics,
    );

    final drillIncidents = [
      Incident(
        id: 'drill-003',
        rtId: 'rt-01',
        shortId: 44001,
        hazard: HazardType.banjir,
        mode: IncidentMode.latihan,
        message: 'Simulasi banjir luapan sungai - evaluasi jalur evakuasi',
        startedBy: 'user-pengurus-1',
        startedAt: DateTime.now().subtract(const Duration(days: 3)),
        endedAt: DateTime.now().subtract(const Duration(days: 3, hours: -1)),
        status: IncidentStatus.selesai,
        metrics: {
          't90': 21,
          't100': 32,
          'vuln_reached_30': 89.0,
          'offline_delivery': 74.0,
          't_recap': 35,
        },
      ),
      Incident(
        id: 'drill-002',
        rtId: 'rt-01',
        shortId: 44002,
        hazard: HazardType.banjir,
        mode: IncidentMode.latihan,
        message: 'Latihan kesiapsiagaan tim relawan blok B',
        startedBy: 'user-pengurus-1',
        startedAt: DateTime.now().subtract(const Duration(days: 14)),
        endedAt: DateTime.now().subtract(const Duration(days: 14, hours: -1)),
        status: IncidentStatus.selesai,
        metrics: {
          't90': 28,
          't100': 42,
          'vuln_reached_30': 78.0,
          'offline_delivery': 60.0,
          't_recap': 48,
        },
      ),
    ];

    state = state.copyWith(
      isLoading: false,
      drillComparison: summary,
      drillIncidents: drillIncidents,
      realIncidents: const [],
    );
  }
}

final historyProvider = StateNotifierProvider<HistoryNotifier, HistoryState>((ref) {
  final authState = ref.watch(authProvider);
  final notifier = HistoryNotifier();
  final rtId = authState.selectedRT?.id ?? 'rt-01';
  notifier.loadHistory(rtId);
  return notifier;
});
