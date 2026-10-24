import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core/core.dart';
import 'package:ui/ui.dart';
import 'package:warga/app/warga_state.dart';
import 'package:warga/features/report/report_page.dart';
import 'package:warga/features/report/outbox_status_sheet.dart';
import 'package:warga/features/beacon_checkin/beacon_checkin_sheet.dart';
import 'package:warga/features/first_aid/first_aid_page.dart';
import 'package:warga/features/education/education_page.dart';

class _TestNotifier extends WargaNotifier {
  _TestNotifier(WargaState initial) : super() {
    state = initial;
  }
}

void main() {
  const phoneSmall = Size(360, 640);
  const phoneStandard = Size(390, 844);

  Widget createTestWidget({
    required Widget child,
    WargaState? initialState,
    Size viewport = phoneStandard,
  }) {
    return ProviderScope(
      overrides: [
        if (initialState != null)
          wargaProvider.overrideWith((ref) => _TestNotifier(initialState)),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        home: MediaQuery(
          data: MediaQueryData(size: viewport),
          child: child,
        ),
      ),
    );
  }

  group('Transactional Outbox & Delivery Status Tests (FR-SYNC-01, FR-RPT-05..06)', () {
    test('Online connection mode marks submitted report as terkirim', () {
      final notifier = WargaNotifier();
      notifier.setConnectionMode(ConnectionMode.online);
      notifier.submitQuickReport(ReportStatus.aman);

      expect(notifier.state.latestReport, isNotNull);
      expect(notifier.state.latestReport!.status, ReportStatus.aman);
      expect(notifier.state.latestDeliveryStatus, DeliveryStatus.terkirim);
      expect(notifier.state.pendingOutboxCount, 0);
      expect(notifier.state.syncStatus, 'synced');
    });

    test('BLE Mesh Relay mode marks submitted report as diteruskanRelay', () {
      final notifier = WargaNotifier();
      notifier.setConnectionMode(ConnectionMode.meshRelay);
      notifier.submitQuickReport(ReportStatus.aman);

      expect(notifier.state.latestReport, isNotNull);
      expect(notifier.state.latestDeliveryStatus, DeliveryStatus.diteruskanRelay);
      expect(notifier.state.syncStatus, 'relay');
      expect(notifier.state.outbox.first.relayHopNode, isNotNull);
    });

    test('Offline mode queues report in transactional outbox as tersimpanLokal', () {
      final notifier = WargaNotifier();
      notifier.setConnectionMode(ConnectionMode.offline);
      notifier.submitQuickReport(ReportStatus.aman);

      expect(notifier.state.latestReport, isNotNull);
      expect(notifier.state.latestDeliveryStatus, DeliveryStatus.tersimpanLokal);
      expect(notifier.state.pendingOutboxCount, 1);
      expect(notifier.state.syncStatus, 'pending');

      // Reconnect and sync outbox
      notifier.setConnectionMode(ConnectionMode.online);
      expect(notifier.state.pendingOutboxCount, 0);
      expect(notifier.state.latestDeliveryStatus, DeliveryStatus.terkirim);
      expect(notifier.state.syncStatus, 'synced');
    });
  });

  group('Beacon Assembly Point Check-in Tests (FR-BCN-05..06, AC-06)', () {
    test('Beacon check-in records beaconId and beacon_checkin channel', () {
      final notifier = WargaNotifier();
      notifier.triggerBeaconCheckin(
        beaconId: 'BCN-RW02-01',
        beaconName: 'Balai RW 02',
      );

      expect(notifier.state.latestReport, isNotNull);
      expect(notifier.state.latestReport!.status, ReportStatus.titikKumpul);
      expect(notifier.state.latestReport!.beaconId, 'BCN-RW02-01');
      expect(notifier.state.latestReport!.channel, 'beacon_checkin');
    });

    test('Beacon range toggle updates discovery state', () {
      final notifier = WargaNotifier();
      expect(notifier.state.beaconInRange, isTrue);
      notifier.toggleBeaconInRange(false);
      expect(notifier.state.beaconInRange, isFalse);
      notifier.toggleBeaconInRange(true);
      expect(notifier.state.beaconInRange, isTrue);
    });
  });

  group('Help Report Urgency & Bitmask Validation Tests (FR-RPT-02)', () {
    test('Help report calculates bitmask for needs and affected members', () {
      final notifier = WargaNotifier();
      notifier.submitHelpReport(
        urgency: ReportUrgency.kritis,
        needs: ['Evakuasi', 'Bantuan Medis & Obat'],
        affectedMemberIds: ['mem-01', 'mem-03'],
        notes: 'Air naik cepat, kakek butuh evakuasi perahu',
      );

      final rpt = notifier.state.latestReport!;
      expect(rpt.status, ReportStatus.butuhBantuan);
      expect(rpt.urgency, ReportUrgency.kritis);
      expect(ReportNeeds.hasNeed(rpt.needs, ReportNeeds.evakuasi), isTrue);
      expect(ReportNeeds.hasNeed(rpt.needs, ReportNeeds.medis), isTrue);
      expect(rpt.message, 'Air naik cepat, kakek butuh evakuasi perahu');
    });
  });

  group('Operational Flow Widgets Multi-Viewport Tests', () {
    testWidgets('ReportPage renders with zero overflow on Small Phone (360x640)', (tester) async {
      await tester.binding.setSurfaceSize(phoneSmall);
      await tester.pumpWidget(createTestWidget(
        child: const ReportPage(),
        viewport: phoneSmall,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Formulir Butuh Bantuan'), findsOneWidget);
      expect(find.text('1. Tingkat Urgensi Bantuan'), findsOneWidget);
      expect(find.text('2. Kebutuhan Bantuan Utama'), findsOneWidget);
      expect(find.byType(SingleChildScrollView), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('OutboxStatusSheet renders with zero overflow on Small Phone', (tester) async {
      await tester.binding.setSurfaceSize(phoneSmall);
      await tester.pumpWidget(createTestWidget(
        child: const Scaffold(body: OutboxStatusSheet()),
        viewport: phoneSmall,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Antrean Pengiriman Laporan'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('BeaconCheckinSheet renders with zero overflow on Small Phone', (tester) async {
      await tester.binding.setSurfaceSize(phoneSmall);
      await tester.pumpWidget(createTestWidget(
        child: const Scaffold(body: BeaconCheckinSheet()),
        viewport: phoneSmall,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Deteksi Beacon Titik Kumpul'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('FirstAidPage renders search, chips, and guides without overflow', (tester) async {
      await tester.binding.setSurfaceSize(phoneSmall);
      await tester.pumpWidget(createTestWidget(
        child: const FirstAidPage(),
        viewport: phoneSmall,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Panduan P3K Darurat'), findsOneWidget);
      expect(find.text('Semua'), findsOneWidget);
      expect(find.text('Darurat Kritis'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('EducationPage renders all 3 tabs without overflow', (tester) async {
      await tester.binding.setSurfaceSize(phoneSmall);
      await tester.pumpWidget(createTestWidget(
        child: const EducationPage(),
        viewport: phoneSmall,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Modul & Kuis'), findsOneWidget);
      expect(find.text('Tas Siaga 72 Jam'), findsOneWidget);
      expect(find.text('Rencana Evakuasi'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
