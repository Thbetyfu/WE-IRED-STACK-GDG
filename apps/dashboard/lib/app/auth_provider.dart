import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core/core.dart';

class AuthState {
  final bool isAuthenticated;
  final bool isLoading;
  final String? token;
  final String? refreshToken;
  final User? user;
  final String? role;
  final String? regionId;
  final String? householdId;
  final List<Region> accessibleRTs;
  final Region? selectedRT;
  final String connectionMode; // 'cloud', 'posko', 'offline'
  final String? errorMessage;

  const AuthState({
    this.isAuthenticated = false,
    this.isLoading = false,
    this.token,
    this.refreshToken,
    this.user,
    this.role,
    this.regionId,
    this.householdId,
    this.accessibleRTs = const [],
    this.selectedRT,
    this.connectionMode = 'cloud',
    this.errorMessage,
  });

  AuthState copyWith({
    bool? isAuthenticated,
    bool? isLoading,
    String? token,
    String? refreshToken,
    User? user,
    String? role,
    String? regionId,
    String? householdId,
    List<Region>? accessibleRTs,
    Region? selectedRT,
    String? connectionMode,
    String? errorMessage,
  }) {
    return AuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      isLoading: isLoading ?? this.isLoading,
      token: token ?? this.token,
      refreshToken: refreshToken ?? this.refreshToken,
      user: user ?? this.user,
      role: role ?? this.role,
      regionId: regionId ?? this.regionId,
      householdId: householdId ?? this.householdId,
      accessibleRTs: accessibleRTs ?? this.accessibleRTs,
      selectedRT: selectedRT ?? this.selectedRT,
      connectionMode: connectionMode ?? this.connectionMode,
      errorMessage: errorMessage,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final ApiClient? apiClient;
  final SessionStorage? sessionStorage;

  AuthNotifier({
    this.apiClient,
    this.sessionStorage,
  }) : super(const AuthState());

  /// Log in via Email and Argon2id Password (FR-AUTH-02).
  Future<bool> loginWithPassword(String email, String password) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      if (apiClient != null) {
        final resp = await apiClient!.post('/auth/login', data: {
          'email': email,
          'password': password,
        });

        final data = resp.data['data'];
        final accessToken = data['access_token'] as String;
        final refreshToken = data['refresh_token'] as String;
        final userData = data['user'];

        final user = User(
          id: userData['id'] as String,
          name: userData['name'] as String,
          phone: userData['phone'] as String,
          email: userData['email'] as String?,
          role: userData['role'] as String,
          regionId: userData['region_id'] as String,
          householdId: userData['household_id'] as String?,
        );

        if (sessionStorage != null) {
          await sessionStorage!.saveSession(AuthSession(
            token: accessToken,
            refreshToken: refreshToken,
            user: user,
            role: user.role,
            regionId: user.regionId,
            householdId: user.householdId,
            expiresAt: DateTime.now().add(const Duration(minutes: 15)),
          ));
        }

        state = state.copyWith(
          isAuthenticated: true,
          isLoading: false,
          token: accessToken,
          refreshToken: refreshToken,
          user: user,
          role: user.role,
          regionId: user.regionId,
          householdId: user.householdId,
        );

        await fetchAccessibleRTs();
        return true;
      } else {
        // Mock fallback for testing without live backend
        final user = User(
          id: 'user-pengurus-1',
          name: 'Pak RT Budi',
          phone: '+62812345678',
          email: email,
          role: 'pengurus',
          regionId: 'rt-01',
        );

        final defaultRT = Region(
          id: 'rt-01',
          type: RegionType.rt,
          name: 'RT 01 / RW 05',
          code: 'RT-01',
        );

        state = state.copyWith(
          isAuthenticated: true,
          isLoading: false,
          token: 'mock-jwt-token',
          user: user,
          role: 'pengurus',
          regionId: 'rt-01',
          accessibleRTs: [defaultRT],
          selectedRT: defaultRT,
        );
        return true;
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
      return false;
    }
  }

  /// Request WhatsApp OTP (FR-AUTH-01, FR-AUTH-08).
  Future<bool> requestOTP(String phone) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      if (apiClient != null) {
        await apiClient!.post('/auth/otp/request', data: {
          'phone': phone,
        });
      }
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  /// Verify WhatsApp OTP and login (FR-AUTH-01).
  Future<bool> verifyOTP(String phone, String code) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      if (apiClient != null) {
        final resp = await apiClient!.post('/auth/otp/verify', data: {
          'phone': phone,
          'code': code,
        });

        final data = resp.data['data'];
        final accessToken = data['access_token'] as String;
        final refreshToken = data['refresh_token'] as String;
        final userData = data['user'];

        final user = User(
          id: userData['id'] as String,
          name: userData['name'] as String,
          phone: userData['phone'] as String,
          email: userData['email'] as String?,
          role: userData['role'] as String,
          regionId: userData['region_id'] as String,
          householdId: userData['household_id'] as String?,
        );

        state = state.copyWith(
          isAuthenticated: true,
          isLoading: false,
          token: accessToken,
          refreshToken: refreshToken,
          user: user,
          role: user.role,
          regionId: user.regionId,
          householdId: user.householdId,
        );

        await fetchAccessibleRTs();
        return true;
      } else {
        final user = User(
          id: 'user-otp-1',
          name: 'Relawan Ahmad',
          phone: phone,
          role: 'admin_wilayah',
          regionId: 'rw-05',
        );

        final rt1 = Region(id: 'rt-01', type: RegionType.rt, name: 'RT 01', code: 'RT-01');
        final rt2 = Region(id: 'rt-02', type: RegionType.rt, name: 'RT 02', code: 'RT-02');

        state = state.copyWith(
          isAuthenticated: true,
          isLoading: false,
          token: 'mock-jwt-token',
          user: user,
          role: 'admin_wilayah',
          regionId: 'rw-05',
          accessibleRTs: [rt1, rt2],
          selectedRT: rt1,
        );
        return true;
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  /// Fetch list of accessible RTs for current authenticated user role (FR-MRT-01).
  Future<void> fetchAccessibleRTs() async {
    if (apiClient == null) return;

    try {
      final resp = await apiClient!.get('/rts');
      final list = (resp.data['data'] as List)
          .map((item) => Region.fromJson(item as Map<String, dynamic>))
          .toList();

      state = state.copyWith(
        accessibleRTs: list,
        selectedRT: list.isNotEmpty ? (state.selectedRT ?? list.first) : null,
      );
    } catch (_) {}
  }

  /// Change active selected RT.
  void selectRT(Region rt) {
    state = state.copyWith(selectedRT: rt);
  }

  /// Set connectivity mode (Cloud, Posko, Offline).
  void setConnectionMode(String mode) {
    state = state.copyWith(connectionMode: mode);
  }

  /// Log out and clear state.
  Future<void> logout() async {
    try {
      if (apiClient != null && state.refreshToken != null) {
        await apiClient!.post('/auth/logout', data: {
          'refresh_token': state.refreshToken,
        });
      }
      if (sessionStorage != null) {
        await sessionStorage!.clear();
      }
    } catch (_) {}

    state = const AuthState();
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});
