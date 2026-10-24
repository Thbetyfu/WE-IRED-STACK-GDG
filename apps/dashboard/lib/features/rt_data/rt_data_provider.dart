import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core/core.dart';

import '../../app/auth_provider.dart';
import 'rt_data_model.dart';

class RtDataState {
  final bool isLoading;
  final bool isSubmitting;
  final String? errorMessage;
  final String? successMessage;

  // Master Data
  final List<Household> households;
  final Map<String, List<Member>> membersByHousehold;
  final Map<String, Consent?> consentsByHousehold;
  final List<Block> blocks;
  final List<Volunteer> volunteers;
  final List<AssemblyPoint> assemblyPoints;

  // CSV Import State
  final CsvImportResult? lastImportResult;

  const RtDataState({
    this.isLoading = false,
    this.isSubmitting = false,
    this.errorMessage,
    this.successMessage,
    this.households = const [],
    this.membersByHousehold = const {},
    this.consentsByHousehold = const {},
    this.blocks = const [],
    this.volunteers = const [],
    this.assemblyPoints = const [],
    this.lastImportResult,
  });

  bool get isEmpty => !isLoading && households.isEmpty;

  RtDataState copyWith({
    bool? isLoading,
    bool? isSubmitting,
    String? errorMessage,
    String? successMessage,
    List<Household>? households,
    Map<String, List<Member>>? membersByHousehold,
    Map<String, Consent?>? consentsByHousehold,
    List<Block>? blocks,
    List<Volunteer>? volunteers,
    List<AssemblyPoint>? assemblyPoints,
    CsvImportResult? lastImportResult,
  }) {
    return RtDataState(
      isLoading: isLoading ?? this.isLoading,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: errorMessage,
      successMessage: successMessage,
      households: households ?? this.households,
      membersByHousehold: membersByHousehold ?? this.membersByHousehold,
      consentsByHousehold: consentsByHousehold ?? this.consentsByHousehold,
      blocks: blocks ?? this.blocks,
      volunteers: volunteers ?? this.volunteers,
      assemblyPoints: assemblyPoints ?? this.assemblyPoints,
      lastImportResult: lastImportResult ?? this.lastImportResult,
    );
  }
}

class RtDataNotifier extends StateNotifier<RtDataState> {
  final ApiClient? apiClient;

  RtDataNotifier({this.apiClient}) : super(const RtDataState());

  void clearMessages() {
    state = state.copyWith(errorMessage: null, successMessage: null);
  }

  /// Load all RT master data (Households, Blocks, Volunteers, Assembly Points).
  Future<void> loadAllData(String rtId) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    if (apiClient == null) {
      _loadBaselineData(rtId);
      return;
    }

    try {
      // 1. Households
      final hhResp = await apiClient!.get('/rts/$rtId/households');
      final hhList = (hhResp.data['data'] as List<dynamic>? ?? [])
          .map((e) => Household.fromJson(e as Map<String, dynamic>))
          .toList();

      // 2. Blocks
      final blkResp = await apiClient!.get('/rts/$rtId/blocks');
      final blkList = (blkResp.data['data'] as List<dynamic>? ?? [])
          .map((e) => Block.fromJson(e as Map<String, dynamic>))
          .toList();

      // 3. Volunteers
      final volResp = await apiClient!.get('/rts/$rtId/volunteers');
      final volList = (volResp.data['data'] as List<dynamic>? ?? [])
          .map((e) => Volunteer.fromJson(e as Map<String, dynamic>))
          .toList();

      // 4. Assembly Points
      final apResp = await apiClient!.get('/rts/$rtId/assembly-points');
      final apList = (apResp.data['data'] as List<dynamic>? ?? [])
          .map((e) => AssemblyPoint.fromJson(e as Map<String, dynamic>))
          .toList();

      state = state.copyWith(
        isLoading: false,
        households: hhList,
        blocks: blkList,
        volunteers: volList,
        assemblyPoints: apList,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Gagal memuat data RT: ${e.toString()}',
      );
    }
  }

  /// Create new Household (FR-HH-01).
  Future<bool> createHousehold(String rtId, Map<String, dynamic> data) async {
    state = state.copyWith(isSubmitting: true, errorMessage: null, successMessage: null);

    if (apiClient == null) {
      final newHh = Household(
        id: 'hh-${DateTime.now().millisecondsSinceEpoch}',
        rtId: rtId,
        number: data['number'] ?? 'A-99',
        address: data['address'] ?? 'Jl. Mawar',
        headName: data['head_name'] ?? 'Warga Baru',
        waPhone: data['wa_phone'] ?? '6281200001111',
        blockId: data['block_id'],
        lat: data['lat'],
        lon: data['lon'],
        inviteCode: 'INV-DEMO',
      );
      state = state.copyWith(
        isSubmitting: false,
        households: [...state.households, newHh],
        successMessage: 'Rumah tangga berhasil ditambahkan (Mode Demo)',
      );
      return true;
    }

    try {
      final resp = await apiClient!.post('/rts/$rtId/households', data: data);
      final created = Household.fromJson(resp.data['data'] as Map<String, dynamic>);
      state = state.copyWith(
        isSubmitting: false,
        households: [...state.households, created],
        successMessage: 'Rumah tangga ${created.number} berhasil ditambahkan',
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: 'Gagal menambahkan rumah tangga: ${e.toString()}',
      );
      return false;
    }
  }

  /// Regenerate and dispatch invite code (FR-HH-04).
  Future<bool> regenerateInvite(String householdId) async {
    state = state.copyWith(isSubmitting: true, errorMessage: null, successMessage: null);

    if (apiClient == null) {
      final updatedList = state.households.map((h) {
        if (h.id == householdId) {
          return Household(
            id: h.id,
            rtId: h.rtId,
            number: h.number,
            address: h.address,
            headName: h.headName,
            waPhone: h.waPhone,
            blockId: h.blockId,
            lat: h.lat,
            lon: h.lon,
            inviteCode: 'INV-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
          );
        }
        return h;
      }).toList();

      state = state.copyWith(
        isSubmitting: false,
        households: updatedList,
        successMessage: 'Kode undangan baru berhasil dibuat dan dikirimkan via WhatsApp',
      );
      return true;
    }

    try {
      final resp = await apiClient!.post('/households/$householdId/invite');
      final newCode = resp.data['data']['invite_code'] as String;

      final updatedList = state.households.map((h) {
        if (h.id == householdId) {
          return Household(
            id: h.id,
            rtId: h.rtId,
            number: h.number,
            address: h.address,
            headName: h.headName,
            waPhone: h.waPhone,
            blockId: h.blockId,
            lat: h.lat,
            lon: h.lon,
            inviteCode: newCode,
          );
        }
        return h;
      }).toList();

      state = state.copyWith(
        isSubmitting: false,
        households: updatedList,
        successMessage: 'Kode undangan $newCode berhasil dikirimkan via WhatsApp',
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: 'Gagal memperbarui kode undangan: ${e.toString()}',
      );
      return false;
    }
  }

  /// Import CSV Data with per-row validation reporting (FR-HH-05).
  Future<bool> importCSV(String rtId, String csvContent) async {
    state = state.copyWith(isSubmitting: true, errorMessage: null, successMessage: null);

    if (apiClient == null) {
      // Simulate parser and row-by-row validation report
      final lines = csvContent.trim().split('\n');
      final dataLines = lines.length > 1 ? lines.sublist(1) : <String>[];
      final total = dataLines.length;

      final List<CsvRowError> errors = [];
      int imported = 0;

      for (int i = 0; i < dataLines.length; i++) {
        final cols = dataLines[i].split(',');
        if (cols.length < 3 || cols[0].trim().isEmpty) {
          errors.add(CsvRowError(
            row: i + 2,
            field: 'nomor_rumah',
            message: 'Nomor rumah tidak boleh kosong',
          ));
        } else {
          imported++;
        }
      }

      final result = CsvImportResult(
        totalRows: total,
        importedCount: imported,
        failedCount: errors.length,
        errors: errors,
      );

      state = state.copyWith(
        isSubmitting: false,
        lastImportResult: result,
        successMessage: errors.isEmpty
            ? 'Impor CSV berhasil: $imported data rumah tangga diimpor'
            : 'Impor CSV selesai dengan beberapa catatan kesalahan',
      );
      return true;
    }

    try {
      final resp = await apiClient!.post(
        '/rts/$rtId/households/import',
        data: {'csv_content': csvContent},
      );
      final result = CsvImportResult.fromJson(resp.data['data'] as Map<String, dynamic>);

      state = state.copyWith(
        isSubmitting: false,
        lastImportResult: result,
        successMessage: result.errors.isEmpty
            ? 'Impor CSV berhasil: ${result.importedCount} data diimpor'
            : 'Impor CSV selesai dengan ${result.failedCount} kesalahan baris',
      );

      // Reload households
      await loadAllData(rtId);
      return true;
    } catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: 'Gagal mengimpor CSV: ${e.toString()}',
      );
      return false;
    }
  }

  /// Toggle Volunteer Availability (FR-VOL-03).
  Future<bool> toggleVolunteerAvailability(String rtId, String volunteerId, bool currentAvailable) async {
    final nextAvailable = !currentAvailable;

    if (apiClient == null) {
      final updatedList = state.volunteers.map((v) {
        if (v.userId == volunteerId) {
          return v.copyWith(available: nextAvailable);
        }
        return v;
      }).toList();

      state = state.copyWith(
        volunteers: updatedList,
        successMessage: 'Status ketersediaan relawan berhasil diperbarui',
      );
      return true;
    }

    try {
      await apiClient!.patch('/rts/$rtId/volunteers/$volunteerId/availability', data: {
        'available': nextAvailable,
      });

      final updatedList = state.volunteers.map((v) {
        if (v.userId == volunteerId) {
          return v.copyWith(available: nextAvailable);
        }
        return v;
      }).toList();

      state = state.copyWith(
        volunteers: updatedList,
        successMessage: 'Status ketersediaan relawan berhasil diperbarui',
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        errorMessage: 'Gagal memperbarui ketersediaan relawan: ${e.toString()}',
      );
      return false;
    }
  }

  /// Create new Assembly Point (FR-AP-01).
  Future<bool> createAssemblyPoint(String rtId, Map<String, dynamic> data) async {
    state = state.copyWith(isSubmitting: true, errorMessage: null, successMessage: null);

    if (apiClient == null) {
      final newAp = AssemblyPoint(
        id: 'ap-${DateTime.now().millisecondsSinceEpoch}',
        rtId: rtId,
        name: data['name'] ?? 'Titik Kumpul Baru',
        lat: data['lat'] ?? -6.2088,
        lon: data['lon'] ?? 106.8456,
        capacity: data['capacity'] ?? 50,
      );
      state = state.copyWith(
        isSubmitting: false,
        assemblyPoints: [...state.assemblyPoints, newAp],
        successMessage: 'Titik kumpul evakuasi berhasil ditambahkan',
      );
      return true;
    }

    try {
      final resp = await apiClient!.post('/rts/$rtId/assembly-points', data: data);
      final created = AssemblyPoint.fromJson(resp.data['data'] as Map<String, dynamic>);
      state = state.copyWith(
        isSubmitting: false,
        assemblyPoints: [...state.assemblyPoints, created],
        successMessage: 'Titik kumpul ${created.name} berhasil ditambahkan',
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: 'Gagal menambahkan titik kumpul: ${e.toString()}',
      );
      return false;
    }
  }

  void _loadBaselineData(String rtId) {
    final now = DateTime.now();

    final households = [
      Household(
        id: 'hh-01',
        rtId: rtId,
        blockId: 'blk-a',
        number: 'A-01',
        address: 'Jl. Kenanga No. 1',
        headName: 'Budi Prasetyo',
        waPhone: '6281234567890',
        hasDevice: true,
        shortId: '8f2a1b9c',
        inviteCode: 'INV-A1B2',
        lat: -6.2085,
        lon: 106.8450,
      ),
      Household(
        id: 'hh-02',
        rtId: rtId,
        blockId: 'blk-a',
        number: 'A-02',
        address: 'Jl. Kenanga No. 2',
        headName: 'Siti Rahma',
        waPhone: '6281987654321',
        hasDevice: true,
        shortId: '7e1c4d2f',
        inviteCode: 'INV-7K11',
        lat: -6.2087,
        lon: 106.8453,
      ),
      Household(
        id: 'hh-03',
        rtId: rtId,
        blockId: 'blk-b',
        number: 'B-04',
        address: 'Jl. Mawar No. 4',
        headName: 'Ahmad Yani',
        waPhone: '6285711223344',
        hasDevice: false,
        shortId: '3d9e2a1b',
        inviteCode: 'INV-B4Y2',
        lat: -6.2092,
        lon: 106.8460,
      ),
    ];

    final blocks = [
      Block(id: 'blk-a', rtId: rtId, name: 'Blok A'),
      Block(id: 'blk-b', rtId: rtId, name: 'Blok B'),
      Block(id: 'blk-c', rtId: rtId, name: 'Blok C'),
    ];

    final volunteers = [
      Volunteer(
        userId: 'vol-01',
        rtId: rtId,
        name: 'Hendra Setiawan',
        phone: '6281299887766',
        skills: ['P3K', 'Evakuasi'],
        available: true,
        assignedBlocks: ['blk-a'],
        createdAt: now.subtract(const Duration(days: 30)),
      ),
      Volunteer(
        userId: 'vol-02',
        rtId: rtId,
        name: 'Dewi Lestari',
        phone: '6281355443322',
        skills: ['Logistik', 'Dapur Umum'],
        available: false,
        assignedBlocks: ['blk-b'],
        createdAt: now.subtract(const Duration(days: 20)),
      ),
    ];

    final assemblyPoints = [
      AssemblyPoint(
        id: 'ap-01',
        rtId: rtId,
        name: 'Balai RW 03 (Utama)',
        lat: -6.2080,
        lon: 106.8455,
        capacity: 120,
        facilities: {'toilet': true, 'listrik': true, 'air': true, 'wheelchair': true},
        contact: 'Pak RW (0812334455)',
      ),
      AssemblyPoint(
        id: 'ap-02',
        rtId: rtId,
        name: 'Lapangan Badminton RT 05 (Cadangan)',
        lat: -6.2095,
        lon: 106.8470,
        capacity: 60,
        facilities: {'toilet': false, 'listrik': true, 'air': true},
      ),
    ];

    state = state.copyWith(
      isLoading: false,
      households: households,
      blocks: blocks,
      volunteers: volunteers,
      assemblyPoints: assemblyPoints,
    );
  }
}

final rtDataProvider = StateNotifierProvider<RtDataNotifier, RtDataState>((ref) {
  final authState = ref.watch(authProvider);
  final notifier = RtDataNotifier(apiClient: authState.apiClient);
  final rtId = authState.selectedRT?.id ?? 'rt-01';
  notifier.loadAllData(rtId);
  return notifier;
});
