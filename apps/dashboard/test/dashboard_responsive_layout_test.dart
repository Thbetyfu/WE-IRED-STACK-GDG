import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ui/ui.dart';

import 'package:dashboard/app/auth_provider.dart';
import 'package:dashboard/app/dashboard_shell.dart';
import 'package:dashboard/features/incident_overview/incident_overview_page.dart';
import 'package:dashboard/features/triage/triage_page.dart';
import 'package:dashboard/features/assignments/assignments_page.dart';
import 'package:dashboard/features/recap/recap_page.dart';
import 'package:dashboard/features/rt_data/rt_data_page.dart';
import 'package:dashboard/features/announcements/announcements_page.dart';
import 'package:dashboard/features/topology/topology_page.dart';
import 'package:dashboard/features/education/education_page.dart';
import 'package:dashboard/features/history_drills/history_page.dart';
import 'package:dashboard/features/posko/posko_page.dart';
import 'package:dashboard/features/map/map_page.dart';
import 'package:dashboard/features/region/region_page.dart';
import 'package:dashboard/features/audit/audit_page.dart';

void assertNoOverflow(WidgetTester tester) {
  final err = tester.takeException();
  if (err != null) {
    print('=== OVERFLOW DETECTED ===');
    print(err);
    if (err is FlutterError) {
      for (final d in err.diagnostics) {
        print('DIAGNOSTIC: ${d.name} -> ${d.toDescription()}');
        for (final sub in d.getChildren()) {
          print('  SUB: ${sub.name} -> ${sub.toDescription()}');
          for (final sub2 in sub.getChildren()) {
            print('    SUB2: ${sub2.name} -> ${sub2.toDescription()}');
          }
        }
      }
    }
  }
  expect(err, isNull);
}

void main() {
  Widget buildTestableWidget({
    required Widget child,
    required AuthNotifier authNotifier,
    Size viewport = const Size(1440, 900),
  }) {
    return ProviderScope(
      overrides: [
        authProvider.overrideWith((ref) => authNotifier),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: MediaQuery(
          data: MediaQueryData(size: viewport),
          child: SizedBox(
            width: viewport.width,
            height: viewport.height,
            child: child,
          ),
        ),
      ),
    );
  }

  group('DashboardShell Responsive Layout Tests', () {
    testWidgets('Desktop Viewport (1440x900): Sidebar is full-width (240px) with sections', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final authNotifier = AuthNotifier();
      await authNotifier.loginWithPassword('pengurus@rt01.id', 'SandiPengurus2026');

      await tester.pumpWidget(
        buildTestableWidget(
          authNotifier: authNotifier,
          viewport: const Size(1440, 900),
          child: const DashboardShell(
            child: IncidentOverviewPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Brand and Sidebar expanded items
      expect(find.text('WE-IRED'), findsOneWidget);
      expect(find.text('Posko & RT Command'), findsOneWidget);
      expect(find.text('OPERASI INSIDEN'), findsOneWidget);
      expect(find.text('Ringkasan Insiden'), findsOneWidget);
      expect(find.text('Triase & Prioritas'), findsOneWidget);
      expect(find.text('Pak RT Budi'), findsOneWidget);

      // Verify Topbar region selector and connection pill
      expect(find.text('RT 01 / RW 05'), findsOneWidget);
      expect(find.text('Cloud Online'), findsOneWidget);

      // Verify no overflow error occurred
      assertNoOverflow(tester);
    });

    testWidgets('Tablet Viewport (1024x768 Landscape): Sidebar auto-collapses to rail (70px)', (tester) async {
      FlutterError.onError = (details) {
        FlutterError.dumpErrorToConsole(details, forceReport: true);
      };
      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final authNotifier = AuthNotifier();
      await authNotifier.loginWithPassword('pengurus@rt01.id', 'SandiPengurus2026');

      await tester.pumpWidget(
        buildTestableWidget(
          authNotifier: authNotifier,
          viewport: const Size(1024, 768),
          child: const DashboardShell(
            child: IncidentOverviewPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // In rail mode, text labels in sidebar are hidden to give room to content canvas
      expect(find.text('OPERASI INSIDEN'), findsNothing);
      expect(find.text('Ringkasan Insiden'), findsNothing);

      // Navigation rail icons are present
      expect(find.byIcon(Icons.dashboard_outlined), findsOneWidget);
      expect(find.byIcon(Icons.medical_services_outlined), findsOneWidget);

      // Content header is rendered without overflow
      expect(find.textContaining('Ringkasan Operasi'), findsOneWidget);
      expect(find.text('Perbarui Data'), findsOneWidget);

      assertNoOverflow(tester);
    });

    testWidgets('Tablet Viewport (768x1024 Portrait): Content renders with zero overflow', (tester) async {
      tester.view.physicalSize = const Size(768, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final authNotifier = AuthNotifier();
      await authNotifier.loginWithPassword('pengurus@rt01.id', 'SandiPengurus2026');

      await tester.pumpWidget(
        buildTestableWidget(
          authNotifier: authNotifier,
          viewport: const Size(768, 1024),
          child: const DashboardShell(
            child: IncidentOverviewPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Topbar and Page header adapt cleanly
      expect(find.textContaining('Ringkasan Operasi'), findsOneWidget);
      expect(find.text('Cloud Online'), findsOneWidget);

      // No overflow
      assertNoOverflow(tester);
    });

    testWidgets('Sidebar manual toggle expands and collapses properly', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final authNotifier = AuthNotifier();
      await authNotifier.loginWithPassword('pengurus@rt01.id', 'SandiPengurus2026');

      await tester.pumpWidget(
        buildTestableWidget(
          authNotifier: authNotifier,
          viewport: const Size(1440, 900),
          child: const DashboardShell(
            child: IncidentOverviewPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Ringkasan Insiden'), findsOneWidget);

      // Click collapse button in sidebar brand header
      final collapseBtn = find.byTooltip('Ciutkan Sidebar');
      expect(collapseBtn, findsOneWidget);
      await tester.tap(collapseBtn);
      await tester.pumpAndSettle();

      // Now labels are hidden
      expect(find.text('Ringkasan Insiden'), findsNothing);

      // Click expand button in topbar
      final expandBtn = find.byTooltip('Perluas Sidebar');
      expect(expandBtn, findsOneWidget);
      await tester.tap(expandBtn);
      await tester.pumpAndSettle();

      // Expanded again
      expect(find.text('Ringkasan Insiden'), findsOneWidget);
    });

    testWidgets('Connection pill toggles between Cloud, Posko, and Offline', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final authNotifier = AuthNotifier();
      await authNotifier.loginWithPassword('pengurus@rt01.id', 'SandiPengurus2026');

      await tester.pumpWidget(
        buildTestableWidget(
          authNotifier: authNotifier,
          viewport: const Size(1280, 800),
          child: const DashboardShell(
            child: IncidentOverviewPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.descendant(of: find.byType(ConnectionStatusPill), matching: find.text('Cloud Online')), findsOneWidget);

      // Tap connection status pill
      await tester.tap(find.byType(ConnectionStatusPill));
      await tester.pumpAndSettle();
      expect(find.descendant(of: find.byType(ConnectionStatusPill), matching: find.text('Posko Lokal')), findsOneWidget);

      await tester.tap(find.byType(ConnectionStatusPill));
      await tester.pumpAndSettle();
      expect(find.descendant(of: find.byType(ConnectionStatusPill), matching: find.text('Offline (Lokal)')), findsOneWidget);

      await tester.tap(find.byType(ConnectionStatusPill));
      await tester.pumpAndSettle();
      expect(find.descendant(of: find.byType(ConnectionStatusPill), matching: find.text('Cloud Online')), findsOneWidget);
    });
  });

  group('Page-Level Responsiveness and Overflow Verification', () {
    final viewports = <String, Size>{
      'Desktop Wide (1440x900)': const Size(1440, 900),
      'Desktop Standard (1280x800)': const Size(1280, 800),
      'Tablet Landscape (1024x768)': const Size(1024, 768),
      'Tablet Portrait (768x1024)': const Size(768, 1024),
    };

    for (final entry in viewports.entries) {
      final name = entry.key;
      final size = entry.value;

      testWidgets('IncidentOverviewPage renders without overflow on $name', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final authNotifier = AuthNotifier();
        await authNotifier.loginWithPassword('pengurus@rt01.id', 'SandiPengurus2026');

        await tester.pumpWidget(
          buildTestableWidget(
            authNotifier: authNotifier,
            viewport: size,
            child: const DashboardShell(child: IncidentOverviewPage()),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.textContaining('Ringkasan Operasi'), findsOneWidget);
        assertNoOverflow(tester);
      });

      testWidgets('TriagePage renders without overflow on $name', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final authNotifier = AuthNotifier();
        await authNotifier.loginWithPassword('pengurus@rt01.id', 'SandiPengurus2026');

        await tester.pumpWidget(
          buildTestableWidget(
            authNotifier: authNotifier,
            viewport: size,
            child: const DashboardShell(child: TriagePage()),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.textContaining('Tabel Triase'), findsOneWidget);
        assertNoOverflow(tester);
      });

      testWidgets('AssignmentsPage renders Kanban board without overflow on $name', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final authNotifier = AuthNotifier();
        await authNotifier.loginWithPassword('pengurus@rt01.id', 'SandiPengurus2026');

        await tester.pumpWidget(
          buildTestableWidget(
            authNotifier: authNotifier,
            viewport: size,
            child: const DashboardShell(child: AssignmentsPage()),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.textContaining('Papan Penugasan Relawan'), findsOneWidget);
        expect(find.text('Disarankan Sistem'), findsOneWidget);
        expect(find.text('Sedang Berjalan'), findsOneWidget);
        expect(find.text('Selesai / Terjangkau'), findsOneWidget);
        assertNoOverflow(tester);
      });

      testWidgets('RecapPage renders without overflow on $name', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final authNotifier = AuthNotifier();
        await authNotifier.loginWithPassword('pengurus@rt01.id', 'SandiPengurus2026');

        await tester.pumpWidget(
          buildTestableWidget(
            authNotifier: authNotifier,
            viewport: size,
            child: const DashboardShell(child: RecapPage()),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.textContaining('Pusat Rekapitulasi'), findsOneWidget);
        assertNoOverflow(tester);
      });

      testWidgets('RtDataPage renders without overflow on $name', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final authNotifier = AuthNotifier();
        await authNotifier.loginWithPassword('pengurus@rt01.id', 'SandiPengurus2026');

        await tester.pumpWidget(
          buildTestableWidget(
            authNotifier: authNotifier,
            viewport: size,
            child: const DashboardShell(child: RtDataPage()),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.textContaining('Manajemen Data RT'), findsOneWidget);
        assertNoOverflow(tester);
      });

      testWidgets('AnnouncementsPage renders without overflow on $name', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final authNotifier = AuthNotifier();
        await authNotifier.loginWithPassword('pengurus@rt01.id', 'SandiPengurus2026');

        await tester.pumpWidget(
          buildTestableWidget(
            authNotifier: authNotifier,
            viewport: size,
            child: const DashboardShell(child: AnnouncementsPage()),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.textContaining('Pusat Siaran Pengumuman'), findsOneWidget);
        assertNoOverflow(tester);
      });

      testWidgets('TopologyPage renders without overflow on $name', (tester) async {
        FlutterError.onError = (details) => FlutterError.dumpErrorToConsole(details, forceReport: true);
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final authNotifier = AuthNotifier();
        await authNotifier.loginWithPassword('pengurus@rt01.id', 'SandiPengurus2026');

        await tester.pumpWidget(
          buildTestableWidget(
            authNotifier: authNotifier,
            viewport: size,
            child: const DashboardShell(child: TopologyPage()),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.textContaining('Topologi Jaringan Mesh BLE'), findsOneWidget);
        assertNoOverflow(tester);
      });

      testWidgets('EducationPage renders without overflow on $name', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final authNotifier = AuthNotifier();
        await authNotifier.loginWithPassword('pengurus@rt01.id', 'SandiPengurus2026');

        await tester.pumpWidget(
          buildTestableWidget(
            authNotifier: authNotifier,
            viewport: size,
            child: const DashboardShell(child: EducationPage()),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.textContaining('Admin Edukasi & Skor Kesiapsiagaan'), findsOneWidget);
        assertNoOverflow(tester);
      });

      testWidgets('HistoryPage renders without overflow on $name', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final authNotifier = AuthNotifier();
        await authNotifier.loginWithPassword('pengurus@rt01.id', 'SandiPengurus2026');

        await tester.pumpWidget(
          buildTestableWidget(
            authNotifier: authNotifier,
            viewport: size,
            child: const DashboardShell(child: HistoryPage()),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.textContaining('Riwayat Insiden & Evaluasi Latihan'), findsOneWidget);
        assertNoOverflow(tester);
      });

      testWidgets('PoskoPage renders without overflow on $name', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final authNotifier = AuthNotifier();
        await authNotifier.loginWithPassword('pengurus@rt01.id', 'SandiPengurus2026');

        await tester.pumpWidget(
          buildTestableWidget(
            authNotifier: authNotifier,
            viewport: size,
            child: const DashboardShell(child: PoskoPage()),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.textContaining('Posko'), findsWidgets);
        assertNoOverflow(tester);
      });

      testWidgets('MapPage renders without overflow on $name', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final authNotifier = AuthNotifier();
        await authNotifier.loginWithPassword('pengurus@rt01.id', 'SandiPengurus2026');

        await tester.pumpWidget(
          buildTestableWidget(
            authNotifier: authNotifier,
            viewport: size,
            child: const DashboardShell(child: MapPage()),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(MapPage), findsOneWidget);
        assertNoOverflow(tester);
      });

      testWidgets('RegionPage renders without overflow on $name for Admin Wilayah', (tester) async {
        FlutterError.onError = (details) => FlutterError.dumpErrorToConsole(details, forceReport: true);
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final authNotifier = AuthNotifier();
        await authNotifier.verifyOTP('+628123456789', '123456');

        await tester.pumpWidget(
          buildTestableWidget(
            authNotifier: authNotifier,
            viewport: size,
            child: const DashboardShell(child: RegionPage()),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.textContaining('Dashboard Agregat Wilayah'), findsOneWidget);
        assertNoOverflow(tester);
      });

      testWidgets('AuditPage renders without overflow on $name for Operator', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final authNotifier = AuthNotifier();
        await authNotifier.loginWithPassword('operator@posko.id', 'SandiOperator2026');

        await tester.pumpWidget(
          buildTestableWidget(
            authNotifier: authNotifier,
            viewport: size,
            child: const DashboardShell(child: AuditPage()),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.textContaining('Audit Log & Rekam Jejak Sistem'), findsOneWidget);
        assertNoOverflow(tester);
      });
    }
  });
}
