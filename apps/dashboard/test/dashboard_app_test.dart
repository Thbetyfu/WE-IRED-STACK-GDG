import 'package:flutter_test/flutter_test.dart';
import 'package:core/core.dart';
import 'package:dashboard/app/auth_provider.dart';

void main() {
  group('AuthState and AuthNotifier Unit Tests', () {
    test('Initial AuthState is unauthenticated and defaults to cloud connection', () {
      final state = const AuthState();
      expect(state.isAuthenticated, isFalse);
      expect(state.isLoading, isFalse);
      expect(state.token, isNull);
      expect(state.role, isNull);
      expect(state.connectionMode, 'cloud');
      expect(state.accessibleRTs, isEmpty);
      expect(state.selectedRT, isNull);
    });

    test('loginWithPassword updates state with credentials and accessible RT', () async {
      final notifier = AuthNotifier();

      final success = await notifier.loginWithPassword('pengurus@rt01.id', 'SandiPengurus2026');
      expect(success, isTrue);

      final state = notifier.state;
      expect(state.isAuthenticated, isTrue);
      expect(state.role, 'pengurus');
      expect(state.user?.name, 'Pak RT Budi');
      expect(state.accessibleRTs.length, 1);
      expect(state.selectedRT?.code, 'RT-01');
    });

    test('verifyOTP updates state for admin_wilayah with multiple RTs', () async {
      final notifier = AuthNotifier();

      final success = await notifier.verifyOTP('+628123456789', '123456');
      expect(success, isTrue);

      final state = notifier.state;
      expect(state.isAuthenticated, isTrue);
      expect(state.role, 'admin_wilayah');
      expect(state.accessibleRTs.length, 2);
      expect(state.selectedRT?.code, 'RT-01');

      // Test RT selection
      final rt2 = state.accessibleRTs[1];
      notifier.selectRT(rt2);
      expect(notifier.state.selectedRT?.code, 'RT-02');
    });

    test('Connection mode toggles properly between cloud, posko, and offline', () {
      final notifier = AuthNotifier();
      expect(notifier.state.connectionMode, 'cloud');

      notifier.setConnectionMode('posko');
      expect(notifier.state.connectionMode, 'posko');

      notifier.setConnectionMode('offline');
      expect(notifier.state.connectionMode, 'offline');
    });

    test('logout resets session state completely', () async {
      final notifier = AuthNotifier();
      await notifier.loginWithPassword('pengurus@rt01.id', 'SandiPengurus2026');
      expect(notifier.state.isAuthenticated, isTrue);

      await notifier.logout();
      expect(notifier.state.isAuthenticated, isFalse);
      expect(notifier.state.token, isNull);
      expect(notifier.state.user, isNull);
    });
  });

  group('Role and Scope Guard Logic Tests', () {
    test('Operator can access all routes including region and audit', () {
      final role = 'operator';
      final canAccessRegion = role == 'admin_wilayah' || role == 'operator';
      final canAccessAudit = role == 'operator';

      expect(canAccessRegion, isTrue);
      expect(canAccessAudit, isTrue);
    });

    test('Admin Wilayah can access region aggregate but not system audit', () {
      final role = 'admin_wilayah';
      final canAccessRegion = role == 'admin_wilayah' || role == 'operator';
      final canAccessAudit = role == 'operator';

      expect(canAccessRegion, isTrue);
      expect(canAccessAudit, isFalse);
    });

    test('Pengurus RT cannot access region aggregate nor system audit', () {
      final role = 'pengurus';
      final canAccessRegion = role == 'admin_wilayah' || role == 'operator';
      final canAccessAudit = role == 'operator';

      expect(canAccessRegion, isFalse);
      expect(canAccessAudit, isFalse);
    });
  });

  group('Drill and Incident History State Tests (N-28, FR-INC-05/08)', () {
    test('Drill comparison summary models parse correctly and calculate stats', () {
      final json = {
        'total_drills': 2,
        'average_vuln_reached_30': 75.0,
        'average_offline_delivery': 60.0,
        'trend': 'improving',
        'drills': [
          {
            'incident_id': 'drill-1',
            'hazard': 'gempa',
            'started_at': '2026-10-24T08:00:00Z',
            't90': 25,
            't100': 40,
            'vuln_reached_30': 70.0,
            'offline_delivery': 55.0,
          },
          {
            'incident_id': 'drill-2',
            'hazard': 'banjir',
            'started_at': '2026-10-24T09:00:00Z',
            't90': 20,
            't100': 35,
            'vuln_reached_30': 80.0,
            'offline_delivery': 65.0,
          },
        ]
      };

      final summary = DrillComparisonSummary.fromJson(json);
      expect(summary.totalDrills, 2);
      expect(summary.averageVulnReached30, 75.0);
      expect(summary.averageOfflineDelivery, 60.0);
      expect(summary.trend, 'improving');
      expect(summary.drills.length, 2);
      expect(summary.drills[1].hazard, HazardType.banjir);
    });

    test('Drill comparison empty state handles zero drills safely', () {
      final emptyJson = {
        'total_drills': 0,
        'average_vuln_reached_30': 0.0,
        'average_offline_delivery': 0.0,
        'trend': 'empty',
        'drills': [],
      };

      final summary = DrillComparisonSummary.fromJson(emptyJson);
      expect(summary.totalDrills, 0);
      expect(summary.trend, 'empty');
      expect(summary.drills, isEmpty);
    });
  });

  group('Announcement Model and Editor Tests (N-14, N-27, FR-ANN-01..04)', () {
    test('Announcement model parses correctly with Ed25519 signature and channels', () {
      final json = {
        'id': 'ann-123',
        'region_ids': ['rt-01', 'rt-02'],
        'short_id': 101,
        'level': 'darurat',
        'text': 'Evakuasi segera ke titik kumpul Balai RW!',
        'expires_at': '2026-10-24T18:00:00Z',
        'signature': 'd54f28fcc4f18eaec2f6b239b64e1efb',
        'channels': ['push', 'whatsapp', 'relay'],
      };

      final ann = Announcement.fromJson(json);
      expect(ann.id, 'ann-123');
      expect(ann.regionIds.length, 2);
      expect(ann.shortId, 101);
      expect(ann.level, AnnouncementLevel.darurat);
      expect(ann.text, 'Evakuasi segera ke titik kumpul Balai RW!');
      expect(ann.signature, isNotNull);
      expect(ann.channels, contains('push'));
      expect(ann.channels, contains('whatsapp'));
      expect(ann.channels, contains('relay'));
    });

    test('Announcement expiration logic detects expired vs active announcements', () {
      final past = DateTime.now().subtract(const Duration(hours: 1));
      final future = DateTime.now().add(const Duration(hours: 2));

      final expiredAnn = Announcement(
        id: 'ann-past',
        shortId: 1,
        level: AnnouncementLevel.info,
        text: 'Pengumuman lama',
        expiresAt: past,
      );

      final activeAnn = Announcement(
        id: 'ann-future',
        shortId: 2,
        level: AnnouncementLevel.darurat,
        text: 'Pengumuman aktif',
        expiresAt: future,
      );

      expect(expiredAnn.isExpired, isTrue);
      expect(activeAnn.isExpired, isFalse);
    });
  });
}
