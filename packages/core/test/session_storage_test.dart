import 'package:test/test.dart';
import 'package:core/core.dart';

void main() {
  group('SessionStorage Tests', () {
    late MemorySessionStorage storage;

    setUp(() {
      storage = MemorySessionStorage();
    });

    test('Saves, reads, and clears user session', () async {
      final session = Session(
        userId: 'usr-001',
        name: 'Pak Darto',
        phone: '+62811223344',
        role: Role.pengurus,
        regionId: 'reg-rt01',
        householdId: 'hh-001',
        accessToken: 'access-token-123',
        refreshToken: 'refresh-token-456',
        householdKey: '0123456789abcdef0123456789abcdef',
        expiresAt: DateTime.now().add(const Duration(minutes: 15)),
      );

      await storage.saveSession(session);

      final retrieved = await storage.getSession();
      expect(retrieved, isNotNull);
      expect(retrieved!.userId, 'usr-001');
      expect(retrieved.role, Role.pengurus);
      expect(retrieved.householdKey, '0123456789abcdef0123456789abcdef');

      final accessToken = await storage.getAccessToken();
      expect(accessToken, 'access-token-123');

      final householdKey = await storage.getHouseholdKey();
      expect(householdKey, '0123456789abcdef0123456789abcdef');

      await storage.clearSession();
      expect(await storage.getSession(), isNull);
      expect(await storage.getAccessToken(), isNull);
    });

    test('Updates rotated tokens in session', () async {
      final session = Session(
        userId: 'usr-002',
        name: 'Rina',
        phone: '+62819876543',
        role: Role.relawan,
        regionId: 'reg-rt01',
        accessToken: 'old-access',
        refreshToken: 'old-refresh',
        expiresAt: DateTime.now().add(const Duration(minutes: 15)),
      );

      await storage.saveSession(session);

      final newExpiresAt = DateTime.now().add(const Duration(minutes: 15));
      await storage.saveTokens(
        accessToken: 'new-access',
        refreshToken: 'new-refresh',
        expiresAt: newExpiresAt,
      );

      expect(await storage.getAccessToken(), 'new-access');
      expect(await storage.getRefreshToken(), 'new-refresh');

      final updatedSession = await storage.getSession();
      expect(updatedSession!.accessToken, 'new-access');
      expect(updatedSession.refreshToken, 'new-refresh');
    });
  });
}
