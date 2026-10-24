import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core/core.dart';

enum TaskPriorityTier {
  kritis,
  mendesak,
  reguler;

  String get label {
    switch (this) {
      case TaskPriorityTier.kritis:
        return 'KRITIS';
      case TaskPriorityTier.mendesak:
        return 'MENDESAK';
      case TaskPriorityTier.reguler:
        return 'REGULER';
    }
  }
}

enum BluetoothRadioStatus {
  active,
  disabled,
  unverified;

  String get label {
    switch (this) {
      case BluetoothRadioStatus.active:
        return 'Bluetooth Aktif (Radio Siaga)';
      case BluetoothRadioStatus.disabled:
        return 'Bluetooth Nonaktif (Mati di Sistem)';
      case BluetoothRadioStatus.unverified:
        return 'Menunggu Izin / Belum Diuji';
    }
  }
}

class VolunteerTask {
  final String id;
  final String householdId;
  final String householdNumber;
  final String headName;
  final String address;
  final String block;
  final double priorityScore;
  final int urgency; // 1: biasa, 2: kritis
  final List<String> needs;
  final String status; // 'disarankan', 'ditugaskan', 'diterima', 'menuju_lokasi', 'dijangkau', 'selesai', 'terkendala', 'ditolak'
  final DateTime assignedAt;
  final String? outreachNotes;
  final String? outcome; // 'aman_di_tempat', 'dievakuasi', 'dirujuk', 'butuh_lanjutan', 'menolak_evakuasi'
  final String? rejectReason;
  final bool hasVulnerable;
  final int vulnerableCount;
  final List<String> vulnerableTypes;
  final double? targetLat;
  final double? targetLon;
  final DateTime? acceptedAt;
  final DateTime? reachedAt;
  final DateTime? completedAt;
  final String syncStatus; // 'synced', 'outbox_queued', 'relay_queued'

  const VolunteerTask({
    required this.id,
    required this.householdId,
    required this.householdNumber,
    required this.headName,
    required this.address,
    required this.block,
    required this.priorityScore,
    required this.urgency,
    required this.needs,
    required this.status,
    required this.assignedAt,
    this.outreachNotes,
    this.outcome,
    this.rejectReason,
    this.hasVulnerable = false,
    this.vulnerableCount = 0,
    this.vulnerableTypes = const [],
    this.targetLat,
    this.targetLon,
    this.acceptedAt,
    this.reachedAt,
    this.completedAt,
    this.syncStatus = 'synced',
  });

  bool get isOverdue {
    if (status == 'selesai') return false;
    return DateTime.now().difference(assignedAt).inMinutes >= 5;
  }

  TaskPriorityTier get priorityTier {
    if (urgency == ReportUrgency.kritis || priorityScore >= 70.0) {
      return TaskPriorityTier.kritis;
    }
    if (priorityScore >= 40.0 || urgency == ReportUrgency.biasa) {
      return TaskPriorityTier.mendesak;
    }
    return TaskPriorityTier.reguler;
  }

  String get statusLabel {
    switch (status.toLowerCase()) {
      case 'disarankan':
        return 'Disarankan';
      case 'ditugaskan':
        return 'Ditugaskan';
      case 'diterima':
        return 'Diterima';
      case 'menuju_lokasi':
      case 'dalam_perjalanan':
        return 'Menuju Lokasi';
      case 'dijangkau':
        return 'Tiba di Lokasi';
      case 'selesai':
        return 'Selesai';
      case 'terkendala':
        return 'Terkendala';
      case 'ditolak':
        return 'Ditolak';
      default:
        return status;
    }
  }

  String? get outcomeLabel {
    if (outcome == null) return null;
    switch (outcome!.toLowerCase()) {
      case 'dievakuasi':
        return 'Dievakuasi ke Titik Kumpul';
      case 'aman_di_tempat':
        return 'Aman Mandiri di Lokasi';
      case 'dirujuk':
        return 'Dirujuk ke Medis / Faskes';
      case 'butuh_lanjutan':
        return 'Butuh Tim / Bantuan Lanjutan';
      case 'menolak_evakuasi':
        return 'Warga Menolak Evakuasi';
      default:
        return outcome;
    }
  }

  VolunteerTask copyWith({
    String? status,
    String? outreachNotes,
    String? outcome,
    String? rejectReason,
    DateTime? acceptedAt,
    DateTime? reachedAt,
    DateTime? completedAt,
    String? syncStatus,
  }) {
    return VolunteerTask(
      id: id,
      householdId: householdId,
      householdNumber: householdNumber,
      headName: headName,
      address: address,
      block: block,
      priorityScore: priorityScore,
      urgency: urgency,
      needs: needs,
      status: status ?? this.status,
      assignedAt: assignedAt,
      outreachNotes: outreachNotes ?? this.outreachNotes,
      outcome: outcome ?? this.outcome,
      rejectReason: rejectReason ?? this.rejectReason,
      hasVulnerable: hasVulnerable,
      vulnerableCount: vulnerableCount,
      vulnerableTypes: vulnerableTypes,
      targetLat: targetLat,
      targetLon: targetLon,
      acceptedAt: acceptedAt ?? this.acceptedAt,
      reachedAt: reachedAt ?? this.reachedAt,
      completedAt: completedAt ?? this.completedAt,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }
}

class ProxyReportEntry {
  final String id;
  final String householdId;
  final String householdNumber;
  final String headName;
  final String address;
  final int status;
  final int urgency;
  final List<String> needs;
  final String notes;
  final DateTime submittedAt;
  final String syncStatus; // 'synced', 'outbox_queued'

  const ProxyReportEntry({
    required this.id,
    required this.householdId,
    required this.householdNumber,
    required this.headName,
    required this.address,
    required this.status,
    required this.urgency,
    required this.needs,
    required this.notes,
    required this.submittedAt,
    this.syncStatus = 'outbox_queued',
  });

  String get statusLabel {
    switch (status) {
      case ReportStatus.aman:
        return 'Aman di Rumah';
      case ReportStatus.titikKumpul:
        return 'Di Titik Kumpul';
      case ReportStatus.butuhBantuan:
        return urgency == ReportUrgency.kritis ? 'Butuh Bantuan (Kritis)' : 'Butuh Bantuan (Biasa)';
      default:
        return 'Status Tidak Diketahui';
    }
  }
}

class RelayPacketItem {
  final String packetId;
  final String source;
  final String sourceNumber;
  final int hopCount;
  final int rssi;
  final DateTime receivedAt;
  final String syncStatus;
  final bool isSynthetic;

  const RelayPacketItem({
    required this.packetId,
    required this.source,
    required this.sourceNumber,
    required this.hopCount,
    required this.rssi,
    required this.receivedAt,
    this.syncStatus = 'Siap Sinkron',
    this.isSynthetic = false,
  });

  String get timeAgo {
    final diff = DateTime.now().difference(receivedAt);
    if (diff.inMinutes < 1) return 'Baru saja';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m lalu';
    return '${diff.inHours}j lalu';
  }
}

class PeerNodeItem {
  final String nodeId;
  final String name;
  final String type;
  final int rssi;
  final int hopCount;
  final String statusLabel;
  final String verificationType;
  final DateTime lastSeen;
  final String dataSource; // 'pindai_langsung' vs 'snapshot_posko'

  const PeerNodeItem({
    required this.nodeId,
    required this.name,
    required this.type,
    required this.rssi,
    required this.hopCount,
    required this.statusLabel,
    required this.verificationType,
    required this.lastSeen,
    this.dataSource = 'pindai_langsung',
  });
}

class BeaconDiagnosticInfo {
  final String beaconId;
  final String name;
  final String location;
  final double lat;
  final double lon;
  final double batteryVoltage;
  final int batteryPercent;
  final double solarVoltage;
  final bool isSolarCharging;
  final int storagePackets;
  final int storageCapacity;
  final int lastHeartbeatSecondsAgo;
  final bool isProvisioned;
  final String provisioningToken;

  const BeaconDiagnosticInfo({
    required this.beaconId,
    required this.name,
    required this.location,
    required this.lat,
    required this.lon,
    required this.batteryVoltage,
    required this.batteryPercent,
    required this.solarVoltage,
    required this.isSolarCharging,
    required this.storagePackets,
    required this.storageCapacity,
    required this.lastHeartbeatSecondsAgo,
    required this.isProvisioned,
    required this.provisioningToken,
  });
}

class RelawanState {
  final String volunteerId;
  final String volunteerName;
  final String assignedBlock;
  final String rtName;
  final Incident? activeIncident;
  final List<VolunteerTask> tasks;
  final bool isCollectorScanning;
  final int collectedPacketsCount;
  final DateTime? lastSyncTime;
  final bool isPoskoConnected;
  final String poskoUrl;
  final String poskoFingerprint;
  final String poskoSsid;
  final int beaconCalibratedRssi;
  final String? notificationMessage;
  final BluetoothRadioStatus bluetoothRadioStatus;
  final List<ProxyReportEntry> proxyReports;
  final List<RelayPacketItem> packetBuffer;
  final List<PeerNodeItem> peerNodes;
  final BeaconDiagnosticInfo beaconInfo;
  final List<int> rssiCalibrationSamples;
  final DateTime? lastPullSyncTime;
  final DateTime? lastPushSyncTime;

  RelawanState({
    this.volunteerId = 'vol-01',
    this.volunteerName = 'Budi Santoso',
    this.assignedBlock = 'Blok A',
    this.rtName = 'RT 05 / RW 02',
    Incident? activeIncident,
    List<VolunteerTask>? tasks,
    this.isCollectorScanning = true,
    this.collectedPacketsCount = 14,
    this.lastSyncTime,
    this.isPoskoConnected = true,
    this.poskoUrl = 'http://weired-posko.local:8080',
    this.poskoFingerprint = 'SHA256:7A:B2:99:E1:3F:88:21',
    this.poskoSsid = 'WEIRED-POSKO-RT05',
    this.beaconCalibratedRssi = -65,
    this.notificationMessage,
    this.bluetoothRadioStatus = BluetoothRadioStatus.active,
    List<ProxyReportEntry>? proxyReports,
    List<RelayPacketItem>? packetBuffer,
    List<PeerNodeItem>? peerNodes,
    BeaconDiagnosticInfo? beaconInfo,
    List<int>? rssiCalibrationSamples,
    this.lastPullSyncTime,
    this.lastPushSyncTime,
  })  : activeIncident = activeIncident ??
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
            ),
        tasks = tasks ??
            [
              VolunteerTask(
                id: 'tsk-01',
                householdId: 'hh-04',
                householdNumber: '04',
                headName: 'Keluarga Bpk. Santoso',
                address: 'Jl. Merak No. 4',
                block: 'Blok A',
                priorityScore: 84.5,
                urgency: ReportUrgency.kritis,
                needs: const ['Evakuasi Medis', 'Lansia Tirah Baring'],
                status: 'diterima',
                assignedAt: DateTime.now().subtract(const Duration(minutes: 8)),
                hasVulnerable: true,
                vulnerableCount: 2,
                vulnerableTypes: const ['Lansia (78 th)', 'Balita (2 th)'],
                targetLat: -6.8909,
                targetLon: 107.6098,
                syncStatus: 'synced',
              ),
              VolunteerTask(
                id: 'tsk-02',
                householdId: 'hh-07',
                householdNumber: '07',
                headName: 'Keluarga Ibu Maryam',
                address: 'Jl. Merak No. 7',
                block: 'Blok A',
                priorityScore: 68.0,
                urgency: ReportUrgency.biasa,
                needs: const ['Makanan / Air Bersih'],
                status: 'disarankan',
                assignedAt: DateTime.now().subtract(const Duration(minutes: 3)),
                hasVulnerable: true,
                vulnerableCount: 1,
                vulnerableTypes: const ['Lansia Hidup Sendiri'],
                targetLat: -6.8912,
                targetLon: 107.6102,
                syncStatus: 'synced',
              ),
              VolunteerTask(
                id: 'tsk-03',
                householdId: 'hh-02',
                householdNumber: '02',
                headName: 'Keluarga Bpk. Ahmad',
                address: 'Jl. Merak No. 2',
                block: 'Blok A',
                priorityScore: 45.0,
                urgency: ReportUrgency.none,
                needs: const ['Aman di Rumah'],
                status: 'selesai',
                outcome: 'aman_di_tempat',
                assignedAt: DateTime.now().subtract(const Duration(minutes: 30)),
                completedAt: DateTime.now().subtract(const Duration(minutes: 10)),
                outreachNotes: 'Warga sudah berada di lantai 2 aman, perbekalan cukup.',
                targetLat: -6.8906,
                targetLon: 107.6095,
                syncStatus: 'synced',
              ),
            ],
        proxyReports = proxyReports ??
            [
              ProxyReportEntry(
                id: 'prx-01',
                householdId: 'hh-02',
                householdNumber: '02',
                headName: 'Keluarga Bpk. Ahmad',
                address: 'Jl. Merak No. 2',
                status: ReportStatus.aman,
                urgency: ReportUrgency.none,
                needs: const [],
                notes: 'Dicek langsung relawan di lantai 2, aman mandiri.',
                submittedAt: DateTime.now().subtract(const Duration(minutes: 25)),
                syncStatus: 'synced',
              ),
            ],
        packetBuffer = packetBuffer ??
            [
              RelayPacketItem(
                packetId: 'PKT-04-SEQ1',
                source: 'Rumah No. 04',
                sourceNumber: '04',
                hopCount: 1,
                rssi: -62,
                receivedAt: DateTime.now().subtract(const Duration(minutes: 2)),
                syncStatus: 'Siap Sinkron',
              ),
              RelayPacketItem(
                packetId: 'PKT-07-SEQ1',
                source: 'Rumah No. 07 (Proksi)',
                sourceNumber: '07',
                hopCount: 0,
                rssi: -45,
                receivedAt: DateTime.now().subtract(const Duration(minutes: 4)),
                syncStatus: 'Siap Sinkron',
              ),
              RelayPacketItem(
                packetId: 'PKT-11-SEQ1',
                source: 'Rumah No. 11',
                sourceNumber: '11',
                hopCount: 2,
                rssi: -78,
                receivedAt: DateTime.now().subtract(const Duration(minutes: 9)),
                syncStatus: 'Siap Sinkron',
              ),
            ],
        peerNodes = peerNodes ??
            [
              PeerNodeItem(
                nodeId: 'BCN-01',
                name: 'WE-IRED Beacon 01 (Balai RW)',
                type: 'Perangkat Keras Beacon ESP32-S3',
                rssi: -58,
                hopCount: 1,
                statusLabel: 'Aktif Menyiarkan',
                verificationType: 'HMAC-SHA256 (Kunci Posko)',
                lastSeen: DateTime.now().subtract(const Duration(seconds: 15)),
                dataSource: 'pindai_langsung',
              ),
              PeerNodeItem(
                nodeId: 'VOL-02',
                name: 'Relawan Siti Aminah (Blok B)',
                type: 'Node Relawan Bergerak',
                rssi: -72,
                hopCount: 2,
                statusLabel: 'Terhubung Mesh',
                verificationType: 'Ed25519 Terverifikasi',
                lastSeen: DateTime.now().subtract(const Duration(minutes: 1)),
                dataSource: 'pindai_langsung',
              ),
              PeerNodeItem(
                nodeId: 'CIT-04',
                name: 'HP Warga (Rumah No. 04)',
                type: 'Pengirim Laporan Mandiri',
                rssi: -64,
                hopCount: 1,
                statusLabel: 'Paket Tertampung',
                verificationType: 'Kunci Rumah (AES-GCM)',
                lastSeen: DateTime.now().subtract(const Duration(minutes: 2)),
                dataSource: 'pindai_langsung',
              ),
            ],
        beaconInfo = beaconInfo ??
            const BeaconDiagnosticInfo(
              beaconId: 'BCN-RW02-01',
              name: 'WE-IRED Beacon Titik Kumpul Balai RW 02',
              location: 'Balai Warga RW 02, Lapangan Utama',
              lat: -6.8915,
              lon: 107.6108,
              batteryVoltage: 4.08,
              batteryPercent: 94,
              solarVoltage: 5.8,
              isSolarCharging: true,
              storagePackets: 18,
              storageCapacity: 5000,
              lastHeartbeatSecondsAgo: 12,
              isProvisioned: true,
              provisioningToken: 'PRV-RW02-2026',
            ),
        rssiCalibrationSamples = rssiCalibrationSamples ?? const [-66, -64, -65, -63, -65];

  int get pendingOutboxCount {
    final taskPending = tasks.where((t) => t.syncStatus != 'synced').length;
    final proxyPending = proxyReports.where((p) => p.syncStatus != 'synced').length;
    return taskPending + proxyPending;
  }

  VolunteerTask? get activeFocusTask {
    try {
      return tasks.firstWhere(
        (t) => t.status == 'diterima' || t.status == 'menuju_lokasi' || t.status == 'dijangkau',
      );
    } catch (_) {
      return null;
    }
  }

  RelawanState copyWith({
    String? volunteerId,
    String? volunteerName,
    String? assignedBlock,
    String? rtName,
    Incident? activeIncident,
    List<VolunteerTask>? tasks,
    bool? isCollectorScanning,
    int? collectedPacketsCount,
    DateTime? lastSyncTime,
    bool? isPoskoConnected,
    String? poskoUrl,
    String? poskoFingerprint,
    String? poskoSsid,
    int? beaconCalibratedRssi,
    String? notificationMessage,
    BluetoothRadioStatus? bluetoothRadioStatus,
    List<ProxyReportEntry>? proxyReports,
    List<RelayPacketItem>? packetBuffer,
    List<PeerNodeItem>? peerNodes,
    BeaconDiagnosticInfo? beaconInfo,
    List<int>? rssiCalibrationSamples,
    DateTime? lastPullSyncTime,
    DateTime? lastPushSyncTime,
  }) {
    return RelawanState(
      volunteerId: volunteerId ?? this.volunteerId,
      volunteerName: volunteerName ?? this.volunteerName,
      assignedBlock: assignedBlock ?? this.assignedBlock,
      rtName: rtName ?? this.rtName,
      activeIncident: activeIncident ?? this.activeIncident,
      tasks: tasks ?? this.tasks,
      isCollectorScanning: isCollectorScanning ?? this.isCollectorScanning,
      collectedPacketsCount: collectedPacketsCount ?? this.collectedPacketsCount,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
      isPoskoConnected: isPoskoConnected ?? this.isPoskoConnected,
      poskoUrl: poskoUrl ?? this.poskoUrl,
      poskoFingerprint: poskoFingerprint ?? this.poskoFingerprint,
      poskoSsid: poskoSsid ?? this.poskoSsid,
      beaconCalibratedRssi: beaconCalibratedRssi ?? this.beaconCalibratedRssi,
      notificationMessage: notificationMessage,
      bluetoothRadioStatus: bluetoothRadioStatus ?? this.bluetoothRadioStatus,
      proxyReports: proxyReports ?? this.proxyReports,
      packetBuffer: packetBuffer ?? this.packetBuffer,
      peerNodes: peerNodes ?? this.peerNodes,
      beaconInfo: beaconInfo ?? this.beaconInfo,
      rssiCalibrationSamples: rssiCalibrationSamples ?? this.rssiCalibrationSamples,
      lastPullSyncTime: lastPullSyncTime ?? this.lastPullSyncTime,
      lastPushSyncTime: lastPushSyncTime ?? this.lastPushSyncTime,
    );
  }
}

class RelawanNotifier extends StateNotifier<RelawanState> {
  RelawanNotifier() : super(RelawanState());

  void updateTaskStatus(
    String taskId,
    String newStatus, {
    String? notes,
    String? outcome,
    String? rejectReason,
    String? syncStatus,
  }) {
    final now = DateTime.now();
    final effectiveSync = syncStatus ?? (state.isPoskoConnected ? 'synced' : 'outbox_queued');

    final updated = state.tasks.map((t) {
      if (t.id == taskId) {
        return t.copyWith(
          status: newStatus,
          outreachNotes: notes,
          outcome: outcome,
          rejectReason: rejectReason,
          acceptedAt: newStatus == 'diterima' ? (t.acceptedAt ?? now) : t.acceptedAt,
          reachedAt: newStatus == 'dijangkau' ? (t.reachedAt ?? now) : t.reachedAt,
          completedAt: newStatus == 'selesai' ? (t.completedAt ?? now) : t.completedAt,
          syncStatus: effectiveSync,
        );
      }
      return t;
    }).toList();

    String message;
    if (newStatus == 'selesai') {
      message = 'Tugas selesai: hasil penjangkauan dicatat (${effectiveSync == 'synced' ? 'Tersinkron' : 'Outbox'})';
    } else if (newStatus == 'diterima') {
      message = 'Tugas diterima. Silakan menuju ke alamat warga.';
    } else if (newStatus == 'menuju_lokasi') {
      message = 'Status diperbarui: Dalam perjalanan menuju lokasi warga.';
    } else if (newStatus == 'dijangkau') {
      message = 'Tiba di lokasi. Periksa kondisi warga dan catat penjangkauan.';
    } else if (newStatus == 'ditolak') {
      message = 'Tugas ditolak dan dialihkan kembali ke antrean Posko.';
    } else {
      message = 'Status tugas berhasil diperbarui ke: ${newStatus.toUpperCase()}';
    }

    state = state.copyWith(
      tasks: updated,
      notificationMessage: message,
    );
  }

  void acceptTask(String taskId) {
    updateTaskStatus(taskId, 'diterima');
  }

  void startTransit(String taskId) {
    updateTaskStatus(taskId, 'menuju_lokasi');
  }

  void reachTask(String taskId) {
    updateTaskStatus(taskId, 'dijangkau');
  }

  void completeTaskWithOutreach(
    String taskId, {
    required String outcome,
    String? notes,
  }) {
    updateTaskStatus(
      taskId,
      'selesai',
      outcome: outcome,
      notes: notes,
    );
  }

  void rejectTask(String taskId, {required String reason}) {
    updateTaskStatus(
      taskId,
      'ditolak',
      rejectReason: reason,
    );
  }

  void togglePoskoConnection([bool? forcedConnected]) {
    final newConnected = forcedConnected ?? !state.isPoskoConnected;
    state = state.copyWith(
      isPoskoConnected: newConnected,
      notificationMessage: newConnected
          ? 'Terhubung kembali ke Posko Lokal. Sinkronisasi outbox aktif.'
          : 'Koneksi Posko terputus. Beralih ke mode mandiri offline (Outbox).',
    );
  }

  void setBluetoothRadioStatus(BluetoothRadioStatus status) {
    state = state.copyWith(
      bluetoothRadioStatus: status,
      isCollectorScanning: status == BluetoothRadioStatus.active ? state.isCollectorScanning : false,
      notificationMessage: 'Status radio Bluetooth diatur ke: ${status.label}',
    );
  }

  void submitProxyReport({
    required String householdId,
    required String householdNumber,
    required int status,
    required int urgency,
    required List<String> needs,
    required String notes,
    String? headName,
    String? address,
  }) {
    final now = DateTime.now();
    final newReport = ProxyReportEntry(
      id: 'prx-${DateTime.now().millisecondsSinceEpoch}',
      householdId: householdId,
      householdNumber: householdNumber,
      headName: headName ?? 'Keluarga Rumah No. $householdNumber',
      address: address ?? 'Jl. Merak No. $householdNumber',
      status: status,
      urgency: urgency,
      needs: needs,
      notes: notes,
      submittedAt: now,
      syncStatus: state.isPoskoConnected ? 'synced' : 'outbox_queued',
    );

    final newPacket = RelayPacketItem(
      packetId: 'PKT-$householdNumber-SEQ${state.collectedPacketsCount + 1}',
      source: 'Rumah No. $householdNumber (Proksi Relawan)',
      sourceNumber: householdNumber,
      hopCount: 0,
      rssi: -40,
      receivedAt: now,
      syncStatus: state.isPoskoConnected ? 'Tersinkron' : 'Siap Sinkron',
    );

    state = state.copyWith(
      proxyReports: [newReport, ...state.proxyReports],
      packetBuffer: [newPacket, ...state.packetBuffer],
      collectedPacketsCount: state.collectedPacketsCount + 1,
      notificationMessage: 'Laporan atas nama Rumah No. $householdNumber berhasil dicatat di outbox.',
    );
  }

  void toggleCollectorScanning(bool enabled) {
    state = state.copyWith(
      isCollectorScanning: enabled,
      notificationMessage: enabled
          ? 'Pemindaian BLE agresif aktif (8s aktif / 4s siaga).'
          : 'Pemindaian BLE dijeda untuk menghemat baterai.',
    );
  }

  void syncCollectedPackets() {
    final now = DateTime.now();
    final syncedTasks = state.tasks.map((t) {
      if (t.syncStatus != 'synced') {
        return t.copyWith(syncStatus: 'synced');
      }
      return t;
    }).toList();

    final syncedProxy = state.proxyReports.map((p) {
      if (p.syncStatus != 'synced') {
        return ProxyReportEntry(
          id: p.id,
          householdId: p.householdId,
          householdNumber: p.householdNumber,
          headName: p.headName,
          address: p.address,
          status: p.status,
          urgency: p.urgency,
          needs: p.needs,
          notes: p.notes,
          submittedAt: p.submittedAt,
          syncStatus: 'synced',
        );
      }
      return p;
    }).toList();

    final syncedPackets = state.packetBuffer.map((p) {
      return RelayPacketItem(
        packetId: p.packetId,
        source: p.source,
        sourceNumber: p.sourceNumber,
        hopCount: p.hopCount,
        rssi: p.rssi,
        receivedAt: p.receivedAt,
        syncStatus: 'Tersinkron',
        isSynthetic: p.isSynthetic,
      );
    }).toList();

    state = state.copyWith(
      tasks: syncedTasks,
      proxyReports: syncedProxy,
      packetBuffer: syncedPackets,
      lastSyncTime: now,
      lastPushSyncTime: now,
      collectedPacketsCount: 0,
      notificationMessage: 'Paket relay dan outbox berhasil disinkronkan ke Posko Lokal.',
    );
  }

  void pullSyncFromPosko() {
    final now = DateTime.now();
    state = state.copyWith(
      lastPullSyncTime: now,
      lastSyncTime: now,
      notificationMessage: 'Pembaruan tugas dan data triase berhasil ditarik dari Posko.',
    );
  }

  void updatePoskoConfig({
    required String url,
    required String fingerprint,
    String? ssid,
  }) {
    state = state.copyWith(
      poskoUrl: url,
      poskoFingerprint: fingerprint,
      poskoSsid: ssid ?? state.poskoSsid,
      isPoskoConnected: true,
      notificationMessage: 'Konfigurasi Posko diperbarui dan terverifikasi.',
    );
  }

  void setBeaconCalibration(int rssi) {
    state = state.copyWith(beaconCalibratedRssi: rssi);
  }

  void runRssiCalibrationSamples(List<int> newSamples) {
    final avg = (newSamples.reduce((a, b) => a + b) / newSamples.length).round();
    state = state.copyWith(
      rssiCalibrationSamples: newSamples,
      beaconCalibratedRssi: avg,
      notificationMessage: 'Kalibrasi 5-sampel selesai: ambang disetel ke $avg dBm.',
    );
  }

  void clearNotificationMessage() {
    state = state.copyWith(notificationMessage: null);
  }
}

final relawanProvider = StateNotifierProvider<RelawanNotifier, RelawanState>((ref) {
  return RelawanNotifier();
});
