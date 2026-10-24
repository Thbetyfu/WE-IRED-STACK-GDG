import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../app/auth_provider.dart';
import 'triage_model.dart';

class TriageState {
  final List<TriageItem> items;
  final List<TriageItem> unreportedItems;
  final TriageItem? selectedItem;
  final String statusFilter;
  final String blockFilter;
  final String vulnerabilityFilter;
  final String channelFilter;
  final String sortBy;
  final String searchQuery;
  final bool isLoading;
  final String? error;

  const TriageState({
    this.items = const [],
    this.unreportedItems = const [],
    this.selectedItem,
    this.statusFilter = 'all',
    this.blockFilter = 'all',
    this.vulnerabilityFilter = 'all',
    this.channelFilter = 'all',
    this.sortBy = 'priority_desc',
    this.searchQuery = '',
    this.isLoading = false,
    this.error,
  });

  TriageState copyWith({
    List<TriageItem>? items,
    List<TriageItem>? unreportedItems,
    TriageItem? selectedItem,
    bool clearSelectedItem = false,
    String? statusFilter,
    String? blockFilter,
    String? vulnerabilityFilter,
    String? channelFilter,
    String? sortBy,
    String? searchQuery,
    bool? isLoading,
    String? error,
  }) {
    return TriageState(
      items: items ?? this.items,
      unreportedItems: unreportedItems ?? this.unreportedItems,
      selectedItem: clearSelectedItem ? null : (selectedItem ?? this.selectedItem),
      statusFilter: statusFilter ?? this.statusFilter,
      blockFilter: blockFilter ?? this.blockFilter,
      vulnerabilityFilter: vulnerabilityFilter ?? this.vulnerabilityFilter,
      channelFilter: channelFilter ?? this.channelFilter,
      sortBy: sortBy ?? this.sortBy,
      searchQuery: searchQuery ?? this.searchQuery,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  List<TriageItem> get filteredItems {
    var result = List<TriageItem>.from(items);

    // Search query
    if (searchQuery.trim().isNotEmpty) {
      final q = searchQuery.toLowerCase().trim();
      result = result.where((item) =>
          item.number.toLowerCase().contains(q) ||
          item.headName.toLowerCase().contains(q) ||
          item.address.toLowerCase().contains(q) ||
          item.blockId.toLowerCase().contains(q)).toList();
    }

    // Status filter
    if (statusFilter != 'all') {
      result = result.where((item) => item.status.toLowerCase() == statusFilter.toLowerCase()).toList();
    }

    // Block filter
    if (blockFilter != 'all') {
      result = result.where((item) =>
          item.blockId.toLowerCase() == blockFilter.toLowerCase() ||
          item.blockId.toLowerCase().contains(blockFilter.toLowerCase())).toList();
    }

    // Vulnerability filter
    if (vulnerabilityFilter == 'vulnerable_only') {
      result = result.where((item) => item.vulnerableCount > 0).toList();
    } else if (vulnerabilityFilter != 'all') {
      result = result.where((item) =>
          item.vulnerableCategories.any((cat) => cat.toLowerCase().contains(vulnerabilityFilter.toLowerCase())) ||
          (item.vulnerableCount > 0 && vulnerabilityFilter == 'lansia')).toList();
    }

    // Channel filter
    if (channelFilter != 'all') {
      result = result.where((item) => item.channel.toLowerCase() == channelFilter.toLowerCase()).toList();
    }

    // Sorting - Strictly using backend priority score without custom client recalculation!
    switch (sortBy) {
      case 'priority_desc':
        result.sort((a, b) {
          final cmp = b.priorityScore.compareTo(a.priorityScore);
          if (cmp != 0) return cmp;
          return b.vulnerableCount.compareTo(a.vulnerableCount);
        });
        break;
      case 'number_asc':
        result.sort((a, b) => a.number.compareTo(b.number));
        break;
      case 'vulnerable_desc':
        result.sort((a, b) => b.vulnerableCount.compareTo(a.vulnerableCount));
        break;
      default:
        result.sort((a, b) => b.priorityScore.compareTo(a.priorityScore));
    }

    return result;
  }
}

class TriageNotifier extends StateNotifier<TriageState> {
  final Ref ref;

  TriageNotifier(this.ref) : super(const TriageState()) {
    loadTriageData();
  }

  void setStatusFilter(String filter) => state = state.copyWith(statusFilter: filter);
  void setBlockFilter(String filter) => state = state.copyWith(blockFilter: filter);
  void setVulnerabilityFilter(String filter) => state = state.copyWith(vulnerabilityFilter: filter);
  void setChannelFilter(String filter) => state = state.copyWith(channelFilter: filter);
  void setSortBy(String sort) => state = state.copyWith(sortBy: sort);
  void setSearchQuery(String query) => state = state.copyWith(searchQuery: query);

  void selectItem(TriageItem? item) async {
    state = state.copyWith(selectedItem: item, clearSelectedItem: item == null);
    if (item != null && item.reportHistory.isEmpty) {
      await fetchHouseholdHistory(item.householdId);
    }
  }

  Future<void> fetchHouseholdHistory(String householdId) async {
    final auth = ref.read(authProvider);
    final baseUrl = auth.baseUrl;
    final token = auth.token;

    try {
      final res = await http.get(
        Uri.parse('$baseUrl/households/$householdId/reports'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final data = body['data'] as List<dynamic>? ?? [];
        final history = data.map((e) => ReportHistoryItem.fromJson(e as Map<String, dynamic>)).toList();

        if (state.selectedItem != null && state.selectedItem!.householdId == householdId) {
          final updatedItem = TriageItem(
            householdId: state.selectedItem!.householdId,
            number: state.selectedItem!.number,
            headName: state.selectedItem!.headName,
            address: state.selectedItem!.address,
            blockId: state.selectedItem!.blockId,
            lat: state.selectedItem!.lat,
            lon: state.selectedItem!.lon,
            status: state.selectedItem!.status,
            urgency: state.selectedItem!.urgency,
            channel: state.selectedItem!.channel,
            priorityScore: state.selectedItem!.priorityScore,
            scoreBreakdown: state.selectedItem!.scoreBreakdown,
            vulnerableCount: state.selectedItem!.vulnerableCount,
            vulnerableCategories: state.selectedItem!.vulnerableCategories,
            reportHistory: history,
          );
          state = state.copyWith(selectedItem: updatedItem);
        }
      }
    } catch (_) {
      // Keep existing history
    }
  }

  Future<void> loadTriageData() async {
    state = state.copyWith(isLoading: true, error: null);
    final auth = ref.read(authProvider);
    final baseUrl = auth.baseUrl;
    final token = auth.token;
    final rtId = auth.selectedRT?.id ?? auth.regionId ?? 'rt-01';

    try {
      // 1. Fetch active incident ID if available
      String incidentId = 'active-incident';
      try {
        final incRes = await http.get(
          Uri.parse('$baseUrl/rts/$rtId/incidents/active'),
          headers: {
            'Content-Type': 'application/json',
            if (token != null) 'Authorization': 'Bearer $token',
          },
        ).timeout(const Duration(seconds: 4));

        if (incRes.statusCode == 200) {
          final incBody = jsonDecode(incRes.body) as Map<String, dynamic>;
          final incData = incBody['data'] as Map<String, dynamic>?;
          if (incData != null && incData['id'] != null) {
            incidentId = incData['id'].toString();
          }
        }
      } catch (_) {}

      // 2. Fetch triage table from backend
      List<TriageItem> items = [];
      try {
        final res = await http.get(
          Uri.parse('$baseUrl/incidents/$incidentId/households?rt_id=$rtId'),
          headers: {
            'Content-Type': 'application/json',
            if (token != null) 'Authorization': 'Bearer $token',
          },
        ).timeout(const Duration(seconds: 5));

        if (res.statusCode == 200) {
          final body = jsonDecode(res.body) as Map<String, dynamic>;
          final data = body['data'] as List<dynamic>? ?? [];
          items = data.map((e) => TriageItem.fromJson(e as Map<String, dynamic>)).toList();
        }
      } catch (_) {}

      // 3. Fetch unreported households
      List<TriageItem> unreported = [];
      try {
        final unrepRes = await http.get(
          Uri.parse('$baseUrl/incidents/$incidentId/unreported'),
          headers: {
            'Content-Type': 'application/json',
            if (token != null) 'Authorization': 'Bearer $token',
          },
        ).timeout(const Duration(seconds: 4));

        if (unrepRes.statusCode == 200) {
          final unrepBody = jsonDecode(unrepRes.body) as Map<String, dynamic>;
          final unrepData = unrepBody['data'] as List<dynamic>? ?? [];
          unreported = unrepData.map((e) => TriageItem.fromJson(e as Map<String, dynamic>)).toList();
        }
      } catch (_) {}

      // Fallback baseline if empty or offline
      if (items.isEmpty) {
        items = _getFallbackItems();
      }
      if (unreported.isEmpty) {
        unreported = items.where((it) => it.status == 'belum_melapor').toList();
      }

      state = state.copyWith(
        items: items,
        unreportedItems: unreported,
        isLoading: false,
      );
    } catch (e) {
      final fallback = _getFallbackItems();
      state = state.copyWith(
        items: fallback,
        unreportedItems: fallback.where((it) => it.status == 'belum_melapor').toList(),
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  List<TriageItem> _getFallbackItems() {
    return [
      TriageItem(
        householdId: 'hh-b04',
        number: 'B-04',
        headName: 'Siti Aminah',
        address: 'Jl. Merdeka No. 4, Blok B',
        blockId: 'Blok B',
        lat: -6.891234,
        lon: 107.610543,
        status: 'kritis',
        urgency: 'kritis',
        channel: 'aplikasi',
        priorityScore: 82.0,
        scoreBreakdown: const ScoreBreakdownModel(u: 40.0, v: 24.0, w: 10.0, n: 4.0, d: 4.0, total: 82.0),
        vulnerableCount: 2,
        vulnerableCategories: const ['Medis (Oksigen)', 'Balita'],
        reportHistory: [
          ReportHistoryItem(
            time: DateTime.now().subtract(const Duration(minutes: 25)),
            status: 'kritis',
            urgency: 'kritis',
            channel: 'aplikasi',
            notes: 'Tabung oksigen sisa 1 jam, air masuk setinggi 40cm',
          ),
          ReportHistoryItem(
            time: DateTime.now().subtract(const Duration(minutes: 50)),
            status: 'butuh_bantuan',
            urgency: 'kritis',
            channel: 'whatsapp',
            notes: 'Mulai tergenang, lansia asma butuh evakuasi',
          ),
        ],
      ),
      TriageItem(
        householdId: 'hh-a12',
        number: 'A-12',
        headName: 'Budi Hartono',
        address: 'Jl. Melati No. 12, Blok A',
        blockId: 'Blok A',
        lat: -6.891890,
        lon: 107.611200,
        status: 'butuh_bantuan',
        urgency: 'biasa',
        channel: 'whatsapp',
        priorityScore: 68.0,
        scoreBreakdown: const ScoreBreakdownModel(u: 30.0, v: 20.0, w: 12.0, n: 4.0, d: 2.0, total: 68.0),
        vulnerableCount: 1,
        vulnerableCategories: const ['Lansia (Stroke)'],
        reportHistory: [
          ReportHistoryItem(
            time: DateTime.now().subtract(const Duration(minutes: 18)),
            status: 'butuh_bantuan',
            urgency: 'biasa',
            channel: 'whatsapp',
            notes: 'Lansia butuh tandu untuk evakuasi ke titik kumpul',
          ),
        ],
      ),
      TriageItem(
        householdId: 'hh-c01',
        number: 'C-01',
        headName: 'Hendro Wijaya',
        address: 'Jl. Kenanga No. 1, Blok C',
        blockId: 'Blok C',
        lat: -6.892450,
        lon: 107.612100,
        status: 'belum_melapor',
        urgency: 'biasa',
        channel: 'belum',
        priorityScore: 42.0,
        scoreBreakdown: const ScoreBreakdownModel(u: 10.0, v: 16.0, w: 14.0, n: 0.0, d: 2.0, total: 42.0),
        vulnerableCount: 1,
        vulnerableCategories: const ['Lansia'],
        reportHistory: const [],
      ),
      TriageItem(
        householdId: 'hh-b08',
        number: 'B-08',
        headName: 'Rahmat Hidayat',
        address: 'Jl. Merdeka No. 8, Blok B',
        blockId: 'Blok B',
        lat: -6.890900,
        lon: 107.610800,
        status: 'belum_melapor',
        urgency: 'biasa',
        channel: 'belum',
        priorityScore: 36.0,
        scoreBreakdown: const ScoreBreakdownModel(u: 10.0, v: 8.0, w: 14.0, n: 0.0, d: 4.0, total: 36.0),
        vulnerableCount: 1,
        vulnerableCategories: const ['Balita'],
        reportHistory: const [],
      ),
      TriageItem(
        householdId: 'hh-a05',
        number: 'A-05',
        headName: 'Dewi Lestari',
        address: 'Jl. Melati No. 5, Blok A',
        blockId: 'Blok A',
        lat: -6.891500,
        lon: 107.611600,
        status: 'titik_kumpul',
        urgency: 'biasa',
        channel: 'relay',
        priorityScore: 18.0,
        scoreBreakdown: const ScoreBreakdownModel(u: 5.0, v: 0.0, w: 8.0, n: 2.0, d: 3.0, total: 18.0),
        vulnerableCount: 0,
        vulnerableCategories: const [],
        reportHistory: [
          ReportHistoryItem(
            time: DateTime.now().subtract(const Duration(minutes: 35)),
            status: 'titik_kumpul',
            urgency: 'biasa',
            channel: 'relay',
            notes: 'Sudah tiba di Titik Kumpul Lapangan RW',
          ),
        ],
      ),
      TriageItem(
        householdId: 'hh-c07',
        number: 'C-07',
        headName: 'Bambang Supardi',
        address: 'Jl. Kenanga No. 7, Blok C',
        blockId: 'Blok C',
        lat: -6.892700,
        lon: 107.612500,
        status: 'aman',
        urgency: 'biasa',
        channel: 'aplikasi',
        priorityScore: 12.0,
        scoreBreakdown: const ScoreBreakdownModel(u: 2.0, v: 0.0, w: 6.0, n: 2.0, d: 2.0, total: 12.0),
        vulnerableCount: 0,
        vulnerableCategories: const [],
        reportHistory: [
          ReportHistoryItem(
            time: DateTime.now().subtract(const Duration(minutes: 40)),
            status: 'aman',
            urgency: 'biasa',
            channel: 'aplikasi',
            notes: 'Keluarga aman di lantai 2',
          ),
        ],
      ),
    ];
  }
}

final triageProvider = StateNotifierProvider<TriageNotifier, TriageState>((ref) {
  return TriageNotifier(ref);
});
