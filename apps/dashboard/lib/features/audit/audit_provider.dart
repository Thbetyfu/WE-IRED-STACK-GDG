import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../app/auth_provider.dart';
import 'audit_model.dart';

class AuditState {
  final List<AuditLogItem> logs;
  final int total;
  final String actionFilter;
  final String searchQuery;
  final bool isLoading;
  final String? error;

  const AuditState({
    this.logs = const [],
    this.total = 0,
    this.actionFilter = 'all',
    this.searchQuery = '',
    this.isLoading = false,
    this.error,
  });

  AuditState copyWith({
    List<AuditLogItem>? logs,
    int? total,
    String? actionFilter,
    String? searchQuery,
    bool? isLoading,
    String? error,
  }) {
    return AuditState(
      logs: logs ?? this.logs,
      total: total ?? this.total,
      actionFilter: actionFilter ?? this.actionFilter,
      searchQuery: searchQuery ?? this.searchQuery,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  List<AuditLogItem> get filteredLogs {
    var result = List<AuditLogItem>.from(logs);

    if (actionFilter != 'all') {
      result = result.where((log) {
        if (actionFilter == 'access_vulnerable_data') {
          return log.action == 'access_vulnerable_data';
        } else if (actionFilter == 'export_recap') {
          return log.action.contains('export') || log.action.contains('recap');
        } else if (actionFilter == 'incident') {
          return log.action.contains('incident');
        } else if (actionFilter == 'ai_settings') {
          return log.action.contains('ai');
        } else if (actionFilter == 'master_data') {
          return log.action.contains('master') || log.action.contains('modify');
        }
        return log.action.toLowerCase() == actionFilter.toLowerCase();
      }).toList();
    }

    if (searchQuery.trim().isNotEmpty) {
      final q = searchQuery.toLowerCase().trim();
      result = result.where((log) =>
          log.userId.toLowerCase().contains(q) ||
          log.action.toLowerCase().contains(q) ||
          log.entity.toLowerCase().contains(q) ||
          log.entityId.toLowerCase().contains(q) ||
          log.details.toString().toLowerCase().contains(q)).toList();
    }

    return result;
  }
}

class AuditNotifier extends StateNotifier<AuditState> {
  final Ref ref;

  AuditNotifier(this.ref) : super(const AuditState()) {
    loadAuditLogs();
  }

  void setActionFilter(String filter) => state = state.copyWith(actionFilter: filter);
  void setSearchQuery(String q) => state = state.copyWith(searchQuery: q);

  Future<void> loadAuditLogs() async {
    state = state.copyWith(isLoading: true, error: null);
    final auth = ref.read(authProvider);
    final baseUrl = auth.baseUrl;
    final token = auth.token;
    final rtId = auth.selectedRT?.id ?? auth.regionId ?? 'rt-01';

    try {
      final res = await http.get(
        Uri.parse('$baseUrl/rts/$rtId/audit-logs?limit=50&offset=0'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final data = body['data'] as List<dynamic>? ?? [];
        final logs = data.map((e) => AuditLogItem.fromJson(e as Map<String, dynamic>)).toList();
        final meta = body['meta'] as Map<String, dynamic>? ?? {};
        final total = (meta['total'] as num?)?.toInt() ?? logs.length;

        state = state.copyWith(
          logs: logs,
          total: total,
          isLoading: false,
        );
      } else {
        throw Exception('Status code: ${res.statusCode}');
      }
    } catch (e) {
      // Fallback baseline for demo & offline inspection
      final fallback = _getFallbackLogs(rtId);
      state = state.copyWith(
        logs: fallback,
        total: fallback.length,
        isLoading: false,
      );
    }
  }

  List<AuditLogItem> _getFallbackLogs(String rtId) {
    final now = DateTime.now();
    return [
      AuditLogItem(
        id: 'aud-001',
        regionId: rtId,
        userId: 'usr-pak-rt',
        action: 'access_vulnerable_data',
        entity: 'household_members',
        entityId: 'hh-b04',
        details: {'reason': 'Verifikasi oksigen darurat', 'category': 'medis'},
        ipAddress: '192.168.1.15',
        userAgent: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/128.0',
        createdAt: now.subtract(const Duration(minutes: 12)),
      ),
      AuditLogItem(
        id: 'aud-002',
        regionId: rtId,
        userId: 'usr-pak-rt',
        action: 'incident_activate',
        entity: 'incident',
        entityId: 'inc-banjir-2026',
        details: {'title': 'Banjir Luapan Cikapundung', 'level': 'merah_darurat'},
        ipAddress: '192.168.1.15',
        userAgent: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/128.0',
        createdAt: now.subtract(const Duration(minutes: 45)),
      ),
      AuditLogItem(
        id: 'aud-003',
        regionId: rtId,
        userId: 'usr-operator-01',
        action: 'export_recap_pdf',
        entity: 'recap',
        entityId: 'rcp-2026-10-24',
        details: {'format': 'pdf', 'rows': 78, 'approval_status': 'approved'},
        ipAddress: '192.168.1.2',
        userAgent: 'Mozilla/5.0 WE-IRED Client',
        createdAt: now.subtract(const Duration(hours: 1, minutes: 10)),
      ),
      AuditLogItem(
        id: 'aud-004',
        regionId: rtId,
        userId: 'usr-pak-rt',
        action: 'update_ai_settings',
        entity: 'region_settings',
        entityId: rtId,
        details: {'ai_enabled': true, 'anonymization_enforced': true},
        ipAddress: '192.168.1.15',
        userAgent: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/128.0',
        createdAt: now.subtract(const Duration(hours: 2, minutes: 20)),
      ),
      AuditLogItem(
        id: 'aud-005',
        regionId: rtId,
        userId: 'usr-admin-wilayah',
        action: 'access_vulnerable_data',
        entity: 'vulnerable_registry',
        entityId: rtId,
        details: {'scope': 'aggregate_only', 'individual_health_notes': 'suppressed'},
        ipAddress: '192.168.10.4',
        userAgent: 'Mozilla/5.0 WebKit/537.36',
        createdAt: now.subtract(const Duration(hours: 3)),
      ),
      AuditLogItem(
        id: 'aud-006',
        regionId: rtId,
        userId: 'usr-pak-rt',
        action: 'master_data_modify',
        entity: 'household',
        entityId: 'hh-a12',
        details: {'field': 'vulnerable_flags', 'action': 'update_contact'},
        ipAddress: '192.168.1.15',
        userAgent: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/128.0',
        createdAt: now.subtract(const Duration(hours: 5)),
      ),
    ];
  }
}

final auditProvider = StateNotifierProvider<AuditNotifier, AuditState>((ref) {
  return AuditNotifier(ref);
});
