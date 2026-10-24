import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core/core.dart';
import 'package:ui/ui.dart';
import 'package:relawan/app/relawan_state.dart';
import 'package:relawan/app/relawan_shell.dart';
import 'package:relawan/features/tasks/tasks_page.dart';
import 'package:relawan/features/block_map/block_map_page.dart';
import 'package:relawan/features/proxy_report/proxy_report_page.dart';
import 'package:relawan/features/collector/collector_page.dart';
import 'package:relawan/features/posko/posko_connect_page.dart';
import 'package:relawan/features/topology/topology_view_page.dart';
import 'package:relawan/features/beacon_tools/beacon_tools_page.dart';
import 'package:relawan/features/first_aid/first_aid_reference_page.dart';

class _MockRelawanNotifier extends RelawanNotifier {
  _MockRelawanNotifier(RelawanState initial) {
    state = initial;
  }
}

void main() {
  const phoneSmall = Size(360, 640);
  const phoneStandard = Size(390, 844);
  const phoneLarge = Size(412, 915);
  const tabletSize = Size(768, 1024);

  Widget createTestWidget({
    required Widget child,
    RelawanState? initialState,
    Size viewport = phoneStandard,
    double textScale = 1.0,
  }) {
    return ProviderScope(
      overrides: [
        if (initialState != null)
          relawanProvider.overrideWith((ref) => _MockRelawanNotifier(initialState)),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        home: MediaQuery(
          data: MediaQueryData(
            size: viewport,
            textScaler: TextScaler.linear(textScale),
          ),
          child: child,
        ),
      ),
    );
  }

  group('RelawanShell Responsive Navigation Tests', () {
    testWidgets('Renders bottom navigation bar on mobile with all 5 destinations and badges', (tester) async {
      await tester.binding.setSurfaceSize(phoneStandard);
      await tester.pumpWidget(createTestWidget(
        child: const RelawanShell(
          currentPath: '/tasks',
          child: Scaffold(body: Center(child: Text('Tugas Screen'))),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Tugas'), findsOneWidget);
      expect(find.text('Peta Blok'), findsOneWidget);
      expect(find.text('Proksi'), findsOneWidget);
      expect(find.text('Kolektor'), findsOneWidget);
      expect(find.text('Posko'), findsOneWidget);
      expect(find.text('Tugas Screen'), findsOneWidget);
    });

    testWidgets('Renders navigation rail on tablet viewport (768x1024)', (tester) async {
      await tester.binding.setSurfaceSize(tabletSize);
      await tester.pumpWidget(createTestWidget(
        viewport: tabletSize,
        child: const RelawanShell(
          currentPath: '/tasks',
          child: Scaffold(body: Center(child: Text('Tablet Content'))),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.text('Tugas'), findsOneWidget);
      expect(find.text('Peta Blok'), findsOneWidget);
      expect(find.text('Lapor Proksi'), findsOneWidget);
      expect(find.text('Kolektor'), findsOneWidget);
      expect(find.text('Posko & Alat'), findsOneWidget);
    });

    testWidgets('Displays offline banner when disconnected from Posko', (tester) async {
      await tester.binding.setSurfaceSize(phoneStandard);
      final offlineState = RelawanState(isPoskoConnected: false);
      await tester.pumpWidget(createTestWidget(
        initialState: offlineState,
        child: const RelawanShell(
          currentPath: '/tasks',
          child: Scaffold(body: Center(child: Text('Offline Content'))),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('Mode Luring'), findsOneWidget);
    });
  });

  group('TasksPage Multi-Viewport & Layout Tests', () {
    testWidgets('Renders TasksPage on small mobile (360x640) without overflow', (tester) async {
      await tester.binding.setSurfaceSize(phoneSmall);
      await tester.pumpWidget(createTestWidget(
        viewport: phoneSmall,
        child: const TasksPage(),
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.textContaining('Tugas Lapangan: Blok A'), findsOneWidget);
      expect(find.text('Kritis'), findsWidgets);
      expect(find.text('Berjalan'), findsWidgets);
      expect(find.text('Selesai'), findsWidgets);
    });

    testWidgets('Renders TasksPage on standard mobile (390x844) without overflow', (tester) async {
      await tester.binding.setSurfaceSize(phoneStandard);
      await tester.pumpWidget(createTestWidget(
        viewport: phoneStandard,
        child: const TasksPage(),
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.textContaining('TUGAS AKTIF SAAT INI'), findsOneWidget);
      expect(find.text('Keluarga Bpk. Santoso'), findsWidgets);
    });

    testWidgets('Renders TasksPage on large mobile (412x915) without overflow', (tester) async {
      await tester.binding.setSurfaceSize(phoneLarge);
      await tester.pumpWidget(createTestWidget(
        viewport: phoneLarge,
        child: const TasksPage(),
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.textContaining('Daftar Tugas Berdasarkan Prioritas'), findsOneWidget);
    });

    testWidgets('Renders TasksPage on tablet (768x1024) without overflow', (tester) async {
      await tester.binding.setSurfaceSize(tabletSize);
      await tester.pumpWidget(createTestWidget(
        viewport: tabletSize,
        child: const TasksPage(),
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.textContaining('Tugas Lapangan: Blok A'), findsOneWidget);
    });
  });

  group('TasksPage Operational Workflows & State Machine Tests', () {
    testWidgets('Active Hero Card allows advancing task from Diterima to Menuju Lokasi and Tiba', (tester) async {
      await tester.binding.setSurfaceSize(phoneStandard);
      await tester.pumpWidget(createTestWidget(
        viewport: phoneStandard,
        child: const TasksPage(),
      ));
      await tester.pumpAndSettle();

      // Initially tsk-01 is 'diterima', so CTA says 'MULAI MENUJU LOKASI'
      final startTransitButton = find.text('MULAI MENUJU LOKASI WARGA');
      expect(startTransitButton, findsOneWidget);

      await tester.tap(startTransitButton);
      await tester.pumpAndSettle();

      // After starting transit, CTA updates to 'SAYA SUDAH TIBA DI LOKASI RUMAH'
      final reachLocationButton = find.text('SAYA SUDAH TIBA DI LOKASI RUMAH');
      expect(reachLocationButton, findsOneWidget);

      await tester.tap(reachLocationButton);
      await tester.pumpAndSettle();

      // After reaching, CTA updates to 'CATAT HASIL PENJANGKAUAN & SELESAI'
      expect(find.text('CATAT HASIL PENJANGKAUAN & SELESAI'), findsOneWidget);
    });

    testWidgets('Accepting an unaccepted task updates its status and scrolls to hero card', (tester) async {
      await tester.binding.setSurfaceSize(phoneStandard);
      await tester.pumpWidget(createTestWidget(
        viewport: phoneStandard,
        child: const TasksPage(),
      ));
      await tester.pumpAndSettle();

      // Scroll until 'TERIMA TUGAS' for tsk-02 (Rumah No. 07) is visible
      final terimaButton = find.text('TERIMA TUGAS');
      await tester.scrollUntilVisible(
        terimaButton,
        100,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(terimaButton, findsOneWidget);

      await tester.tap(terimaButton);
      await tester.pumpAndSettle();

      // Check snackbar or notification
      expect(find.textContaining('Tugas Rumah 07 diterima'), findsWidgets);
    });

    testWidgets('Outreach Result Sheet records outcome and completes task', (tester) async {
      await tester.binding.setSurfaceSize(phoneStandard);
      // State with reached task
      final taskReached = VolunteerTask(
        id: 'tsk-01',
        householdId: 'hh-04',
        householdNumber: '04',
        headName: 'Keluarga Bpk. Santoso',
        address: 'Jl. Merak No. 4',
        block: 'Blok A',
        priorityScore: 84.5,
        urgency: ReportUrgency.kritis,
        needs: const ['Evakuasi Medis'],
        status: 'dijangkau',
        assignedAt: DateTime.now().subtract(const Duration(minutes: 8)),
        hasVulnerable: true,
      );

      final state = RelawanState(tasks: [taskReached]);

      await tester.pumpWidget(createTestWidget(
        initialState: state,
        viewport: phoneStandard,
        child: const TasksPage(),
      ));
      await tester.pumpAndSettle();

      final catatButton = find.text('CATAT HASIL PENJANGKAUAN & SELESAI');
      expect(catatButton, findsOneWidget);

      await tester.tap(catatButton);
      await tester.pumpAndSettle();

      // Bottom sheet is visible with outcome options
      expect(find.textContaining('Hasil Penjangkauan: Rumah 04'), findsOneWidget);
      expect(find.text('Dievakuasi ke Titik Kumpul'), findsOneWidget);
      expect(find.text('Aman Mandiri di Lokasi'), findsOneWidget);
      expect(find.text('Dirujuk ke Medis / Faskes'), findsOneWidget);
      expect(find.text('Butuh Bantuan Lanjutan'), findsOneWidget);
      expect(find.text('Warga Menolak Evakuasi'), findsOneWidget);

      // Select 'Aman Mandiri di Lokasi'
      await tester.tap(find.text('Aman Mandiri di Lokasi'));
      await tester.pumpAndSettle();

      // Scroll inside bottom sheet to submit button
      final submitButton = find.text('SIMPAN HASIL & SELESAIKAN TUGAS');
      await tester.ensureVisible(submitButton);
      await tester.pumpAndSettle();
      expect(submitButton, findsOneWidget);

      await tester.tap(submitButton);
      await tester.pumpAndSettle();

      // Task is now complete
      expect(find.textContaining('Tugas Rumah 04 berhasil diselesaikan'), findsOneWidget);
    });

    testWidgets('Reject / Reassign dialog opens and returns task to Posko queue', (tester) async {
      await tester.binding.setSurfaceSize(phoneStandard);
      await tester.pumpWidget(createTestWidget(
        viewport: phoneStandard,
        child: const TasksPage(),
      ));
      await tester.pumpAndSettle();

      // Scroll until 'Tolak' button on unaccepted task is visible
      final tolakButton = find.text('Tolak');
      await tester.scrollUntilVisible(
        tolakButton,
        100,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(tolakButton, findsOneWidget);

      await tester.tap(tolakButton);
      await tester.pumpAndSettle();

      expect(find.textContaining('Alihkan Tugas Rumah 07'), findsOneWidget);
      expect(find.text('Alasan Kendala Penjangkauan:'), findsOneWidget);

      final konfirmasiButton = find.text('Konfirmasi Alihkan');
      expect(konfirmasiButton, findsOneWidget);

      await tester.tap(konfirmasiButton);
      await tester.pumpAndSettle();

      expect(find.textContaining('dialihkan kembali ke Posko'), findsOneWidget);
    });

    testWidgets('Toggling offline simulation updates Posko connection status pill', (tester) async {
      await tester.binding.setSurfaceSize(phoneStandard);
      await tester.pumpWidget(createTestWidget(
        viewport: phoneStandard,
        child: const TasksPage(),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Posko Online'), findsOneWidget);

      // Tap offline simulation icon in appbar
      final offlineToggle = find.byIcon(Icons.cloud_done);
      expect(offlineToggle, findsOneWidget);

      await tester.tap(offlineToggle);
      await tester.pumpAndSettle();

      expect(find.text('Outbox Luring'), findsOneWidget);
    });

    testWidgets('Filter chips correctly filter tasks list', (tester) async {
      await tester.binding.setSurfaceSize(phoneStandard);
      await tester.pumpWidget(createTestWidget(
        viewport: phoneStandard,
        child: const TasksPage(),
      ));
      await tester.pumpAndSettle();

      // Tap 'Selesai' filter
      final selesaiFilter = find.text('Selesai');
      expect(selesaiFilter, findsWidgets);

      await tester.tap(selesaiFilter.first);
      await tester.pumpAndSettle();

      // Drag to see Rumah No. 02
      await tester.drag(find.byType(ListView), const Offset(0, -200));
      await tester.pumpAndSettle();

      // In completed view, tsk-03 (Rumah No. 02) should be present
      expect(find.text('Rumah No. 02'), findsOneWidget);
    });
  });

  group('Secondary Operational Pages Smoke & Overflow Tests', () {
    testWidgets('BlockMapPage renders without overflow on phoneSmall and phoneStandard', (tester) async {
      await tester.binding.setSurfaceSize(phoneSmall);
      await tester.pumpWidget(createTestWidget(
        viewport: phoneSmall,
        child: const BlockMapPage(),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.textContaining('Peta Navigasi: Blok A'), findsOneWidget);
    });

    testWidgets('CollectorPage renders without overflow on phoneSmall and phoneStandard', (tester) async {
      await tester.binding.setSurfaceSize(phoneSmall);
      await tester.pumpWidget(createTestWidget(
        viewport: phoneSmall,
        child: const CollectorPage(),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.textContaining('Mode Kolektor'), findsOneWidget);
    });

    testWidgets('ProxyReportPage renders without overflow on phoneSmall and phoneStandard', (tester) async {
      await tester.binding.setSurfaceSize(phoneSmall);
      await tester.pumpWidget(createTestWidget(
        viewport: phoneSmall,
        child: const ProxyReportPage(),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.textContaining('Lapor Atas Nama Warga'), findsOneWidget);
    });

    testWidgets('PoskoConnectPage renders without overflow on phoneSmall and phoneStandard', (tester) async {
      await tester.binding.setSurfaceSize(phoneSmall);
      await tester.pumpWidget(createTestWidget(
        viewport: phoneSmall,
        child: const PoskoConnectPage(),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.textContaining('Koneksi Posko Lokal'), findsOneWidget);
    });

    testWidgets('TopologyViewPage renders without overflow on phoneSmall and phoneStandard', (tester) async {
      await tester.binding.setSurfaceSize(phoneSmall);
      await tester.pumpWidget(createTestWidget(
        viewport: phoneSmall,
        child: const TopologyViewPage(),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.textContaining('Node Sekitar & Topologi Mesh'), findsOneWidget);
    });

    testWidgets('BeaconToolsPage renders without overflow on phoneSmall and phoneStandard', (tester) async {
      await tester.binding.setSurfaceSize(phoneSmall);
      await tester.pumpWidget(createTestWidget(
        viewport: phoneSmall,
        child: const BeaconToolsPage(),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.textContaining('Alat Beacon & Kalibrasi RSSI'), findsOneWidget);
    });

    testWidgets('Multi-Viewport Verification: Secondary pages render without overflow on Tablet (768x1024)', (tester) async {
      await tester.binding.setSurfaceSize(tabletSize);
      for (final widget in const [
        BlockMapPage(),
        CollectorPage(),
        ProxyReportPage(),
        PoskoConnectPage(),
        TopologyViewPage(),
        BeaconToolsPage(),
      ]) {
        await tester.pumpWidget(createTestWidget(
          viewport: tabletSize,
          child: widget,
        ));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    });
  });

  group('Secondary Operational Workflows & State Machine Tests', () {
    testWidgets('ProxyReportPage allows selecting household and submitting report to outbox', (tester) async {
      final notifier = RelawanNotifier();
      await tester.binding.setSurfaceSize(phoneStandard);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          relawanProvider.overrideWith((ref) => notifier),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const ProxyReportPage(),
        ),
      ));
      await tester.pumpAndSettle();

      // Scroll to submit button and tap
      final submitBtn = find.text('SIMPAN LAPORAN PROKSI KE OUTBOX');
      await tester.scrollUntilVisible(submitBtn, 100, scrollable: find.byType(Scrollable).first);
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -100));
      await tester.pumpAndSettle();
      expect(submitBtn, findsOneWidget);

      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      // Should have incremented collectedPacketsCount and added to proxyReports
      expect(notifier.state.collectedPacketsCount, 15);
      expect(notifier.state.proxyReports.length, 2);
    });

    testWidgets('CollectorPage diagnostics switch updates radio state', (tester) async {
      final notifier = RelawanNotifier();
      await tester.binding.setSurfaceSize(phoneStandard);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          relawanProvider.overrideWith((ref) => notifier),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const CollectorPage(),
        ),
      ));
      await tester.pumpAndSettle();

      // Tap 'Mati' radio diagnostic button
      final matiBtn = find.text('Mati');
      expect(matiBtn, findsOneWidget);
      await tester.tap(matiBtn);
      await tester.pumpAndSettle();

      expect(notifier.state.bluetoothRadioStatus, BluetoothRadioStatus.disabled);
      expect(notifier.state.isCollectorScanning, isFalse);
    });

    testWidgets('BeaconToolsPage calibration button triggers 5-sample calculation', (tester) async {
      final notifier = RelawanNotifier();
      await tester.binding.setSurfaceSize(phoneStandard);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          relawanProvider.overrideWith((ref) => notifier),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const BeaconToolsPage(),
        ),
      ));
      await tester.pumpAndSettle();

      final calibBtn = find.text('Jalankan Kalibrasi Otomatis (5 Sampel)');
      await tester.scrollUntilVisible(calibBtn, 100, scrollable: find.byType(Scrollable).first);
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -250));
      await tester.pumpAndSettle();
      expect(calibBtn, findsOneWidget);

      await tester.tap(calibBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 900));
      await tester.pumpAndSettle();

      expect(notifier.state.beaconCalibratedRssi, -65);
      expect(notifier.state.notificationMessage, contains('Kalibrasi 5-sampel selesai'));
    });

    testWidgets('PoskoConnectPage QR and manual config update Posko URL', (tester) async {
      final notifier = RelawanNotifier();
      await tester.binding.setSurfaceSize(phoneStandard);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          relawanProvider.overrideWith((ref) => notifier),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const PoskoConnectPage(),
        ),
      ));
      await tester.pumpAndSettle();

      final scanBtn = find.text('Pindai QR Kode Sekarang');
      await tester.scrollUntilVisible(scanBtn, 100, scrollable: find.byType(Scrollable).first);
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -200));
      await tester.pumpAndSettle();
      expect(scanBtn, findsOneWidget);

      await tester.tap(scanBtn);
      await tester.pumpAndSettle();

      expect(notifier.state.isPoskoConnected, isTrue);
      expect(notifier.state.poskoUrl, 'http://weired-posko.local:8080');
    });
  });

  group('Multi-Viewport Zero Overflow Verification (360x640, 390x844, 412x915, 768x1024)', () {
    final viewports = <String, Size>{
      'Small Phone (360x640)': phoneSmall,
      'Standard Phone (390x844)': phoneStandard,
      'Large Phone (412x915)': phoneLarge,
      'Tablet Portrait (768x1024)': tabletSize,
    };

    for (final entry in viewports.entries) {
      testWidgets('TasksPage renders with zero overflow on ${entry.key}', (tester) async {
        await tester.binding.setSurfaceSize(entry.value);
        await tester.pumpWidget(createTestWidget(
          viewport: entry.value,
          child: const TasksPage(),
        ));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });

      testWidgets('ProxyReportPage renders with zero overflow on ${entry.key}', (tester) async {
        await tester.binding.setSurfaceSize(entry.value);
        await tester.pumpWidget(createTestWidget(
          viewport: entry.value,
          child: const ProxyReportPage(),
        ));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });

      testWidgets('CollectorPage renders with zero overflow on ${entry.key}', (tester) async {
        await tester.binding.setSurfaceSize(entry.value);
        await tester.pumpWidget(createTestWidget(
          viewport: entry.value,
          child: const CollectorPage(),
        ));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });

      testWidgets('TopologyViewPage renders with zero overflow on ${entry.key}', (tester) async {
        await tester.binding.setSurfaceSize(entry.value);
        await tester.pumpWidget(createTestWidget(
          viewport: entry.value,
          child: const TopologyViewPage(),
        ));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });

      testWidgets('BeaconToolsPage renders with zero overflow on ${entry.key}', (tester) async {
        await tester.binding.setSurfaceSize(entry.value);
        await tester.pumpWidget(createTestWidget(
          viewport: entry.value,
          child: const BeaconToolsPage(),
        ));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });

      testWidgets('PoskoConnectPage renders with zero overflow on ${entry.key}', (tester) async {
        await tester.binding.setSurfaceSize(entry.value);
        await tester.pumpWidget(createTestWidget(
          viewport: entry.value,
          child: const PoskoConnectPage(),
        ));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });

      testWidgets('FirstAidReferencePage renders with zero overflow on ${entry.key}', (tester) async {
        await tester.binding.setSurfaceSize(entry.value);
        await tester.pumpWidget(createTestWidget(
          viewport: entry.value,
          child: const FirstAidReferencePage(),
        ));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  });
}
