import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core/core.dart';
import 'package:content/content.dart';

/// Connection mode for device communications (FR-SYNC-01, FR-BLE-01..11)
enum ConnectionMode {
  online, // Connected to Posko Wi-Fi or Internet
  meshRelay, // Connected via BLE Relay to nearby volunteers / peers
  offline, // Totally offline, queued in local transactional outbox
}

/// Delivery status of a reported status/need (FR-RPT-05..06, FR-SYNC-01)
enum DeliveryStatus {
  terkirim, // Successfully delivered to Cloud / Posko
  diteruskanRelay, // Relayed through volunteer / neighbor BLE node
  tersimpanLokal, // Stored safely in local transactional outbox
  menungguKoneksi, // Pending reconnection
}

/// Item stored in local outbox queue
class ReportOutboxItem {
  final String id;
  final Report report;
  final DeliveryStatus deliveryStatus;
  final String channel; // 'app', 'beacon_checkin', 'relay_volunteer', 'outbox'
  final DateTime createdAt;
  final DateTime? syncedAt;
  final int retryAttempts;
  final int payloadSizeBytes;
  final String? relayHopNode;

  const ReportOutboxItem({
    required this.id,
    required this.report,
    required this.deliveryStatus,
    required this.channel,
    required this.createdAt,
    this.syncedAt,
    this.retryAttempts = 0,
    this.payloadSizeBytes = 28,
    this.relayHopNode,
  });

  String get statusLabel {
    switch (deliveryStatus) {
      case DeliveryStatus.terkirim:
        return 'Terkirim ke Posko / Cloud';
      case DeliveryStatus.diteruskanRelay:
        return 'Diteruskan via Relay BLE';
      case DeliveryStatus.tersimpanLokal:
        return 'Tersimpan di Outbox Lokal';
      case DeliveryStatus.menungguKoneksi:
        return 'Menunggu Koneksi Jaringan';
    }
  }

  ReportOutboxItem copyWith({
    DeliveryStatus? deliveryStatus,
    DateTime? syncedAt,
    int? retryAttempts,
    String? relayHopNode,
  }) {
    return ReportOutboxItem(
      id: id,
      report: report,
      deliveryStatus: deliveryStatus ?? this.deliveryStatus,
      channel: channel,
      createdAt: createdAt,
      syncedAt: syncedAt ?? this.syncedAt,
      retryAttempts: retryAttempts ?? this.retryAttempts,
      payloadSizeBytes: payloadSizeBytes,
      relayHopNode: relayHopNode ?? this.relayHopNode,
    );
  }
}

class WargaState {
  final bool isAuthenticated;
  final bool isLoading;
  final String? invitationCode;
  final String? phoneNumber;
  final String? householdId;
  final String householdNumber;
  final String headName;
  final String address;
  final String blockName;
  final List<Member> members;
  final bool consentGiven;
  final Incident? activeIncident;
  final Report? latestReport;
  final ConnectionMode connectionMode;
  final List<ReportOutboxItem> outbox;
  final Set<String> checkedBagItemIds;
  final Map<String, int> quizScores; // moduleId -> percentage
  final String familyEvacuationRoute;
  final String primaryMeetingPoint;
  final bool batterySavingMode;
  final bool autoCheckinBeacon;
  final String? statusMessage;

  // Beacon live detection state (FR-BCN-05)
  final bool isScanningBeacon;
  final bool beaconInRange;
  final String? detectedBeaconId;
  final String? detectedBeaconName;
  final int detectedBeaconRssi;

  WargaState({
    this.isAuthenticated = true,
    this.isLoading = false,
    this.invitationCode = 'WRG-RT05-04',
    this.phoneNumber = '081234567890',
    this.householdId = 'hh-04',
    this.householdNumber = '04',
    this.headName = 'Keluarga Bpk. Santoso',
    this.address = 'Jl. Merak No. 4, RT 05 / RW 02',
    this.blockName = 'Blok A',
    this.members = const [
      Member(
        id: 'mem-01',
        householdId: 'hh-04',
        idx: 0,
        name: 'Santoso',
        birthYear: 1958,
        sex: 'L',
        relation: 'kepala',
        vulnFlags: 1, // bit 0: lansia
      ),
      Member(
        id: 'mem-02',
        householdId: 'hh-04',
        idx: 1,
        name: 'Sri Wahyuni',
        birthYear: 1965,
        sex: 'P',
        relation: 'istri',
        vulnFlags: 0,
      ),
      Member(
        id: 'mem-03',
        householdId: 'hh-04',
        idx: 2,
        name: 'Budi Santoso (Lansia Tirah Baring)',
        birthYear: 1938,
        sex: 'L',
        relation: 'orang_tua',
        vulnFlags: 3, // bit 0: lansia, bit 1: disabilitas
        needsEvacAssist: true,
      ),
    ],
    this.consentGiven = true,
    Incident? activeIncident,
    this.latestReport,
    this.connectionMode = ConnectionMode.online,
    this.outbox = const [],
    this.checkedBagItemIds = const {'doc_waterproof', 'drinking_water', 'flashlight_torch', 'first_aid_kit'},
    this.quizScores = const {'mod_banjir': 100, 'mod_gempa': 100},
    this.familyEvacuationRoute = 'Keluar lewat pintu belakang ke gang barat langsung menuju Balai RW',
    this.primaryMeetingPoint = 'Balai Warga RT 05 / RW 02 (Titik Kumpul Utama)',
    this.batterySavingMode = false,
    this.autoCheckinBeacon = true,
    this.statusMessage,
    this.isScanningBeacon = false,
    this.beaconInRange = true,
    this.detectedBeaconId = 'BCN-RW02-01',
    this.detectedBeaconName = 'Balai RW 02 (Titik Kumpul)',
    this.detectedBeaconRssi = -68,
    bool isNormalState = false,
    String? syncStatus,
  })  : activeIncident = isNormalState
            ? null
            : (activeIncident ??
                Incident(
                  id: 'inc-01',
                  rtId: 'rt-05',
                  shortId: 105,
                  hazard: HazardType.banjir,
                  status: IncidentStatus.aktif,
                  mode: IncidentMode.latihan,
                  message: 'Latihan Evakuasi Siaga Banjir RT 05',
                  startedBy: 'Ketua RT 05',
                  startedAt: DateTime(2026, 10, 24, 9, 0),
                )),
        _explicitSyncStatus = syncStatus;

  final String? _explicitSyncStatus;

  bool get isSiaga => activeIncident != null && activeIncident!.isActive;
  bool get isDrill => activeIncident?.isDrill ?? false;

  /// Accurate Outbox Count (pending unsynced items)
  int get pendingOutboxCount => outbox
      .where((item) =>
          item.deliveryStatus == DeliveryStatus.tersimpanLokal ||
          item.deliveryStatus == DeliveryStatus.menungguKoneksi)
      .length;

  /// Dynamically computes sync status based on connection mode and pending outbox
  String get syncStatus {
    if (_explicitSyncStatus != null) return _explicitSyncStatus;
    if (connectionMode == ConnectionMode.offline) {
      return pendingOutboxCount > 0 ? 'pending' : 'offline';
    }
    if (connectionMode == ConnectionMode.meshRelay) {
      return 'relay';
    }
    if (pendingOutboxCount > 0) {
      return 'pending';
    }
    return 'synced';
  }

  DeliveryStatus get latestDeliveryStatus {
    if (outbox.isNotEmpty) {
      return outbox.first.deliveryStatus;
    }
    switch (connectionMode) {
      case ConnectionMode.online:
        return DeliveryStatus.terkirim;
      case ConnectionMode.meshRelay:
        return DeliveryStatus.diteruskanRelay;
      case ConnectionMode.offline:
        return DeliveryStatus.tersimpanLokal;
    }
  }

  int get preparednessScore {
    final moduleScore = (quizScores.length / EducationRepository.modules.length).clamp(0.0, 1.0) * 30;
    final totalQuiz = quizScores.values.isEmpty ? 0 : (quizScores.values.reduce((a, b) => a + b) / quizScores.length);
    final quizPart = (totalQuiz / 100.0).clamp(0.0, 1.0) * 30;
    final bagPart = (checkedBagItemIds.length / EducationRepository.defaultBagItems.length).clamp(0.0, 1.0) * 20;
    final planPart = familyEvacuationRoute.trim().isNotEmpty ? 20.0 : 0.0;
    return (moduleScore + quizPart + bagPart + planPart).round().clamp(0, 100);
  }

  WargaState copyWith({
    bool? isAuthenticated,
    bool? isLoading,
    String? invitationCode,
    String? phoneNumber,
    String? householdId,
    String? householdNumber,
    String? headName,
    String? address,
    String? blockName,
    List<Member>? members,
    bool? consentGiven,
    Incident? activeIncident,
    bool clearIncident = false,
    Report? latestReport,
    ConnectionMode? connectionMode,
    List<ReportOutboxItem>? outbox,
    Set<String>? checkedBagItemIds,
    Map<String, int>? quizScores,
    String? familyEvacuationRoute,
    String? primaryMeetingPoint,
    bool? batterySavingMode,
    bool? autoCheckinBeacon,
    String? statusMessage,
    bool? isScanningBeacon,
    bool? beaconInRange,
    String? detectedBeaconId,
    String? detectedBeaconName,
    int? detectedBeaconRssi,
    String? syncStatus,
  }) {
    return WargaState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      isLoading: isLoading ?? this.isLoading,
      invitationCode: invitationCode ?? this.invitationCode,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      householdId: householdId ?? this.householdId,
      householdNumber: householdNumber ?? this.householdNumber,
      headName: headName ?? this.headName,
      address: address ?? this.address,
      blockName: blockName ?? this.blockName,
      members: members ?? this.members,
      consentGiven: consentGiven ?? this.consentGiven,
      activeIncident: clearIncident ? null : (activeIncident ?? this.activeIncident),
      latestReport: latestReport ?? this.latestReport,
      connectionMode: connectionMode ?? this.connectionMode,
      outbox: outbox ?? this.outbox,
      checkedBagItemIds: checkedBagItemIds ?? this.checkedBagItemIds,
      quizScores: quizScores ?? this.quizScores,
      familyEvacuationRoute: familyEvacuationRoute ?? this.familyEvacuationRoute,
      primaryMeetingPoint: primaryMeetingPoint ?? this.primaryMeetingPoint,
      batterySavingMode: batterySavingMode ?? this.batterySavingMode,
      autoCheckinBeacon: autoCheckinBeacon ?? this.autoCheckinBeacon,
      statusMessage: statusMessage,
      isScanningBeacon: isScanningBeacon ?? this.isScanningBeacon,
      beaconInRange: beaconInRange ?? this.beaconInRange,
      detectedBeaconId: detectedBeaconId ?? this.detectedBeaconId,
      detectedBeaconName: detectedBeaconName ?? this.detectedBeaconName,
      detectedBeaconRssi: detectedBeaconRssi ?? this.detectedBeaconRssi,
      syncStatus: syncStatus,
    );
  }
}

class WargaNotifier extends StateNotifier<WargaState> {
  WargaNotifier() : super(WargaState());

  void authenticate(String code, String phone) {
    state = state.copyWith(
      isAuthenticated: true,
      invitationCode: code,
      phoneNumber: phone,
      statusMessage: 'Aktivasi akun berhasil',
    );
  }

  void logout() {
    state = state.copyWith(isAuthenticated: false);
  }

  void setConnectionMode(ConnectionMode mode) {
    state = state.copyWith(
      connectionMode: mode,
      statusMessage: mode == ConnectionMode.online
          ? 'Terhubung ke Jaringan Posko & Internet'
          : (mode == ConnectionMode.meshRelay
              ? 'Terhubung ke Relay Bluetooth HP Sekitar'
              : 'Mode Luring: Data disimpan di antrean Outbox'),
    );
    if (mode == ConnectionMode.online || mode == ConnectionMode.meshRelay) {
      syncPendingOutbox();
    }
  }

  void toggleSiagaMode() {
    if (state.activeIncident == null) {
      state = state.copyWith(
        activeIncident: Incident(
          id: 'inc-01',
          rtId: 'rt-05',
          shortId: 105,
          hazard: HazardType.banjir,
          status: IncidentStatus.aktif,
          mode: IncidentMode.latihan,
          message: 'Latihan Evakuasi Siaga Banjir RT 05',
          startedBy: 'Ketua RT 05',
          startedAt: DateTime.now(),
        ),
      );
    } else {
      state = state.copyWith(clearIncident: true);
    }
  }

  void toggleDrillMode() {
    if (state.activeIncident != null) {
      final nextMode = state.activeIncident!.mode == IncidentMode.latihan
          ? IncidentMode.nyata
          : IncidentMode.latihan;
      state = state.copyWith(
        activeIncident: Incident(
          id: state.activeIncident!.id,
          rtId: state.activeIncident!.rtId,
          shortId: state.activeIncident!.shortId,
          hazard: state.activeIncident!.hazard,
          status: state.activeIncident!.status,
          mode: nextMode,
          message: state.activeIncident!.message,
          startedBy: state.activeIncident!.startedBy,
          startedAt: state.activeIncident!.startedAt,
        ),
      );
    }
  }

  void submitQuickReport(int statusInt, {String? beaconId, String? beaconName}) {
    final nextSeq = (state.latestReport?.seq ?? 0) + 1;
    final rptId = 'rpt-${DateTime.now().millisecondsSinceEpoch}';

    DeliveryStatus deliveryStatus;
    String channel;

    if (beaconId != null) {
      channel = 'beacon_checkin';
    } else if (state.connectionMode == ConnectionMode.meshRelay) {
      channel = 'relay_volunteer';
    } else if (state.connectionMode == ConnectionMode.offline) {
      channel = 'outbox';
    } else {
      channel = 'app';
    }

    switch (state.connectionMode) {
      case ConnectionMode.online:
        deliveryStatus = DeliveryStatus.terkirim;
        break;
      case ConnectionMode.meshRelay:
        deliveryStatus = DeliveryStatus.diteruskanRelay;
        break;
      case ConnectionMode.offline:
        deliveryStatus = DeliveryStatus.tersimpanLokal;
        break;
    }

    final report = Report(
      id: rptId,
      incidentId: state.activeIncident?.id ?? 'inc-01',
      householdId: state.householdId ?? 'hh-04',
      seq: nextSeq,
      status: statusInt,
      urgency: ReportUrgency.none,
      channel: channel,
      beaconId: beaconId,
      deviceTime: DateTime.now(),
    );

    final outboxItem = ReportOutboxItem(
      id: rptId,
      report: report,
      deliveryStatus: deliveryStatus,
      channel: channel,
      createdAt: DateTime.now(),
      syncedAt: deliveryStatus == DeliveryStatus.terkirim ? DateTime.now() : null,
      payloadSizeBytes: 28,
      relayHopNode: deliveryStatus == DeliveryStatus.diteruskanRelay
          ? 'Relawan Blok A (Budi)'
          : (beaconId != null ? 'Beacon Balai RW' : null),
    );

    state = state.copyWith(
      latestReport: report,
      outbox: [outboxItem, ...state.outbox],
      syncStatus: deliveryStatus == DeliveryStatus.terkirim
          ? 'synced'
          : (deliveryStatus == DeliveryStatus.diteruskanRelay ? 'relay' : 'pending'),
      statusMessage: 'Laporan status ${ReportStatus.label(statusInt)}: ${outboxItem.statusLabel}',
    );
  }

  void submitHelpReport({
    required int urgency,
    required List<String> needs,
    required List<String> affectedMemberIds,
    required String notes,
  }) {
    int needsMask = 0;
    for (final need in needs) {
      if (need.toLowerCase().contains('evakuasi')) needsMask |= ReportNeeds.evakuasi;
      if (need.toLowerCase().contains('medis')) needsMask |= ReportNeeds.medis;
      if (need.toLowerCase().contains('makanan') || need.toLowerCase().contains('air') || need.toLowerCase().contains('logistik')) {
        needsMask |= ReportNeeds.logistik;
      }
      if (need.toLowerCase().contains('tempat') || need.toLowerCase().contains('tenda') || need.toLowerCase().contains('selimut')) {
        needsMask |= ReportNeeds.tempatTinggal;
      }
    }
    if (needsMask == 0) needsMask = ReportNeeds.lainnya;

    // Bitmask affected members
    int memberMask = 0;
    for (int i = 0; i < state.members.length; i++) {
      if (affectedMemberIds.contains(state.members[i].id)) {
        memberMask |= (1 << i);
      }
    }

    final nextSeq = (state.latestReport?.seq ?? 0) + 1;
    final rptId = 'rpt-${DateTime.now().millisecondsSinceEpoch}';

    DeliveryStatus deliveryStatus;
    String channel;

    if (state.connectionMode == ConnectionMode.meshRelay) {
      channel = 'relay_volunteer';
      deliveryStatus = DeliveryStatus.diteruskanRelay;
    } else if (state.connectionMode == ConnectionMode.offline) {
      channel = 'outbox';
      deliveryStatus = DeliveryStatus.tersimpanLokal;
    } else {
      channel = 'app';
      deliveryStatus = DeliveryStatus.terkirim;
    }

    final report = Report(
      id: rptId,
      incidentId: state.activeIncident?.id ?? 'inc-01',
      householdId: state.householdId ?? 'hh-04',
      seq: nextSeq,
      status: ReportStatus.butuhBantuan,
      urgency: urgency,
      needs: needsMask,
      memberMask: memberMask,
      message: notes,
      channel: channel,
      deviceTime: DateTime.now(),
    );

    final outboxItem = ReportOutboxItem(
      id: rptId,
      report: report,
      deliveryStatus: deliveryStatus,
      channel: channel,
      createdAt: DateTime.now(),
      syncedAt: deliveryStatus == DeliveryStatus.terkirim ? DateTime.now() : null,
      payloadSizeBytes: 64, // Help reports include message
      relayHopNode: deliveryStatus == DeliveryStatus.diteruskanRelay ? 'Relawan Blok A (Budi)' : null,
    );

    state = state.copyWith(
      latestReport: report,
      outbox: [outboxItem, ...state.outbox],
      syncStatus: deliveryStatus == DeliveryStatus.terkirim
          ? 'synced'
          : (deliveryStatus == DeliveryStatus.diteruskanRelay ? 'relay' : 'pending'),
      statusMessage: urgency == ReportUrgency.kritis
          ? 'Laporan KRITIS disiarkan: ${outboxItem.statusLabel}'
          : 'Laporan Bantuan disiarkan: ${outboxItem.statusLabel}',
    );
  }

  void syncPendingOutbox() {
    if (state.connectionMode == ConnectionMode.offline) {
      state = state.copyWith(statusMessage: 'Tidak ada koneksi. Outbox tetap disimpan di perangkat.');
      return;
    }

    final updated = state.outbox.map((item) {
      if (item.deliveryStatus == DeliveryStatus.tersimpanLokal ||
          item.deliveryStatus == DeliveryStatus.menungguKoneksi) {
        return item.copyWith(
          deliveryStatus: state.connectionMode == ConnectionMode.online
              ? DeliveryStatus.terkirim
              : DeliveryStatus.diteruskanRelay,
          syncedAt: DateTime.now(),
          relayHopNode: state.connectionMode == ConnectionMode.meshRelay ? 'Relawan Blok A (Budi)' : null,
        );
      }
      return item;
    }).toList();

    state = state.copyWith(
      outbox: updated,
      statusMessage: 'Semua item outbox berhasil disinkronkan',
    );
  }

  void retryOutboxItem(String id) {
    final updated = state.outbox.map((item) {
      if (item.id == id) {
        if (state.connectionMode != ConnectionMode.offline) {
          return item.copyWith(
            deliveryStatus: state.connectionMode == ConnectionMode.online
                ? DeliveryStatus.terkirim
                : DeliveryStatus.diteruskanRelay,
            syncedAt: DateTime.now(),
          );
        } else {
          return item.copyWith(retryAttempts: item.retryAttempts + 1);
        }
      }
      return item;
    }).toList();

    state = state.copyWith(
      outbox: updated,
      statusMessage: state.connectionMode != ConnectionMode.offline
          ? 'Item outbox berhasil dikirim'
          : 'Mencoba kembali... Jaringan belum tersedia.',
    );
  }

  void toggleBeaconInRange(bool inRange) {
    state = state.copyWith(
      beaconInRange: inRange,
      statusMessage: inRange
          ? 'Terdeteksi sinyal Beacon Balai RW 02 (-68 dBm)'
          : 'Di luar jangkauan sinyal Beacon Titik Kumpul',
    );
  }

  void triggerBeaconCheckin({String? beaconId, String? beaconName}) {
    final bId = beaconId ?? state.detectedBeaconId ?? 'BCN-RW02-01';
    final bName = beaconName ?? state.detectedBeaconName ?? 'Balai RW 02';
    submitQuickReport(ReportStatus.titikKumpul, beaconId: bId, beaconName: bName);
  }

  void toggleBagItem(String itemId) {
    final updated = Set<String>.from(state.checkedBagItemIds);
    if (updated.contains(itemId)) {
      updated.remove(itemId);
    } else {
      updated.add(itemId);
    }
    state = state.copyWith(checkedBagItemIds: updated);
  }

  void recordQuizScore(String moduleId, int percentage) {
    final updated = Map<String, int>.from(state.quizScores);
    updated[moduleId] = percentage;
    state = state.copyWith(quizScores: updated);
  }

  void updateEvacuationPlan(String route, String meetingPoint) {
    state = state.copyWith(
      familyEvacuationRoute: route,
      primaryMeetingPoint: meetingPoint,
      statusMessage: 'Rencana evakuasi mandiri berhasil disimpan',
    );
  }

  void toggleConsent(bool value) {
    state = state.copyWith(consentGiven: value);
  }

  void toggleBatteryMode(bool value) {
    state = state.copyWith(batterySavingMode: value);
  }

  void toggleAutoCheckin(bool value) {
    state = state.copyWith(autoCheckinBeacon: value);
  }
}

final wargaProvider = StateNotifierProvider<WargaNotifier, WargaState>((ref) {
  return WargaNotifier();
});
