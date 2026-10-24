import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core/core.dart';

import '../../app/auth_provider.dart';

class AnnouncementsState {
  final bool isLoading;
  final bool isSubmitting;
  final String? errorMessage;
  final String? successMessage;
  final List<Announcement> announcements;

  const AnnouncementsState({
    this.isLoading = false,
    this.isSubmitting = false,
    this.errorMessage,
    this.successMessage,
    this.announcements = const [],
  });

  AnnouncementsState copyWith({
    bool? isLoading,
    bool? isSubmitting,
    String? errorMessage,
    String? successMessage,
    List<Announcement>? announcements,
  }) {
    return AnnouncementsState(
      isLoading: isLoading ?? this.isLoading,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: errorMessage,
      successMessage: successMessage,
      announcements: announcements ?? this.announcements,
    );
  }
}

class AnnouncementsNotifier extends StateNotifier<AnnouncementsState> {
  final ApiClient? apiClient;

  AnnouncementsNotifier({this.apiClient}) : super(const AnnouncementsState());

  Future<void> loadAnnouncements(String rtId) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    if (apiClient == null) {
      _loadBaselineData();
      return;
    }

    try {
      final resp = await apiClient!.get('/rts/$rtId/announcements');
      final list = (resp.data['data'] as List<dynamic>)
          .map((e) => Announcement.fromJson(e as Map<String, dynamic>))
          .toList();

      state = state.copyWith(
        isLoading: false,
        announcements: list,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Gagal memuat pengumuman: $e',
      );
    }
  }

  Future<bool> createAnnouncement({
    required String rtId,
    required AnnouncementLevel level,
    required String text,
    required DateTime expiresAt,
    required List<String> channels,
  }) async {
    if (text.trim().isEmpty) {
      state = state.copyWith(errorMessage: 'Teks pengumuman tidak boleh kosong');
      return false;
    }
    if (text.length > 160) {
      state = state.copyWith(errorMessage: 'Teks pengumuman tidak boleh melebihi 160 karakter');
      return false;
    }
    if (channels.isEmpty) {
      state = state.copyWith(errorMessage: 'Minimal satu kanal distribusi harus dipilih');
      return false;
    }
    if (expiresAt.isBefore(DateTime.now())) {
      state = state.copyWith(errorMessage: 'Waktu kedaluwarsa harus di masa depan');
      return false;
    }

    state = state.copyWith(isSubmitting: true, errorMessage: null, successMessage: null);

    if (apiClient == null) {
      // Standalone/mock creation
      final newAnn = Announcement(
        id: 'ann-${DateTime.now().millisecondsSinceEpoch}',
        regionIds: [rtId],
        shortId: DateTime.now().millisecondsSinceEpoch % 65535,
        level: level,
        text: text.trim(),
        expiresAt: expiresAt,
        signature: 'simulated-ed25519-signature-valid',
        channels: channels,
      );

      final updated = [newAnn, ...state.announcements];
      state = state.copyWith(
        isSubmitting: false,
        successMessage: 'Pengumuman bertanda tangan Ed25519 berhasil disiarkan',
        announcements: updated,
      );
      return true;
    }

    try {
      final payload = {
        'level': level.name,
        'text': text.trim(),
        'expires_at': expiresAt.toUtc().toIso8601String(),
        'channels': channels,
      };

      final resp = await apiClient!.post('/rts/$rtId/announcements', data: payload);
      final data = resp.data['data'] as Map<String, dynamic>;
      final created = Announcement.fromJson(data['announcement'] as Map<String, dynamic>);

      final updated = [created, ...state.announcements];
      state = state.copyWith(
        isSubmitting: false,
        successMessage: 'Pengumuman bertanda tangan Ed25519 berhasil disiarkan',
        announcements: updated,
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: 'Gagal membuat pengumuman: $e',
      );
      return false;
    }
  }

  void _loadBaselineData() {
    final now = DateTime.now();
    final baseline = [
      Announcement(
        id: 'ann-001',
        regionIds: ['rt-01'],
        shortId: 101,
        level: AnnouncementLevel.darurat,
        text: 'Waspada air meningkat di bantaran sungai. Segera menuju titik kumpul Balai RW 05!',
        expiresAt: now.add(const Duration(hours: 4)),
        signature: 'b64ed25519sig-darurat-valid',
        channels: const ['push', 'whatsapp', 'relay'],
      ),
      Announcement(
        id: 'ann-002',
        regionIds: ['rt-01'],
        shortId: 102,
        level: AnnouncementLevel.info,
        text: 'Dapur umum posko telah beroperasi di Balai RW 05. Logistik balita dan lansia tersedia.',
        expiresAt: now.add(const Duration(hours: 12)),
        signature: 'b64ed25519sig-info-valid',
        channels: const ['push', 'relay'],
      ),
    ];

    state = state.copyWith(
      isLoading: false,
      announcements: baseline,
    );
  }
}

final announcementsProvider = StateNotifierProvider<AnnouncementsNotifier, AnnouncementsState>((ref) {
  final authState = ref.watch(authProvider);
  final notifier = AnnouncementsNotifier();
  final rtId = authState.selectedRT?.id ?? 'rt-01';
  notifier.loadAnnouncements(rtId);
  return notifier;
});
