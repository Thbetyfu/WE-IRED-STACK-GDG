import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core/core.dart';
import 'package:ui/ui.dart';
import 'package:warga/app/warga_state.dart';
import 'package:warga/app/warga_shell.dart';
import 'package:warga/features/onboarding/onboarding_page.dart';
import 'package:warga/features/home/home_page.dart';
import 'package:warga/features/announcements/announcements_page.dart';
import 'package:warga/features/household/household_page.dart';
import 'package:warga/features/settings/settings_page.dart';
import 'package:warga/features/education/education_page.dart';
import 'package:warga/features/first_aid/first_aid_page.dart';

void main() {
  const phoneSmall = Size(360, 640);
  const phoneStandard = Size(390, 844);
  const phoneLarge = Size(412, 915);
  const tabletSize = Size(768, 1024);

  Widget createTestWidget({
    required Widget child,
    WargaState? initialState,
    Size viewport = phoneStandard,
    double textScale = 1.0,
  }) {
    return ProviderScope(
      overrides: [
        if (initialState != null)
          wargaProvider.overrideWith((ref) => _MockWargaNotifier(initialState)),
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

  group('WargaShell Navigation Tests', () {
    testWidgets('Renders bottom navigation bar on mobile with all 4 primary destinations', (tester) async {
      await tester.binding.setSurfaceSize(phoneStandard);
      await tester.pumpWidget(createTestWidget(
        child: const WargaShell(
          currentPath: '/',
          child: Scaffold(body: Center(child: Text('Home Content'))),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Beranda'), findsOneWidget);
      expect(find.text('Pengumuman'), findsOneWidget);
      expect(find.text('Siaga & Tas'), findsOneWidget);
      expect(find.text('Rumah Saya'), findsOneWidget);
      expect(find.text('Home Content'), findsOneWidget);
    });

    testWidgets('Renders navigation rail on tablet viewports (>=640px)', (tester) async {
      await tester.binding.setSurfaceSize(tabletSize);
      await tester.pumpWidget(createTestWidget(
        viewport: tabletSize,
        child: const WargaShell(
          currentPath: '/',
          child: Scaffold(body: Center(child: Text('Tablet Body'))),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.text('Tablet Body'), findsOneWidget);
    });
  });

  group('OnboardingPage Accessibility & Flow Tests', () {
    testWidgets('Step 0 allows sample code fill and step navigation without overflow', (tester) async {
      await tester.binding.setSurfaceSize(phoneSmall);
      await tester.pumpWidget(createTestWidget(
        viewport: phoneSmall,
        child: const OnboardingPage(),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Aktivasi Aplikasi Warga'), findsOneWidget);
      expect(find.text('Kode Undangan Rumah'), findsOneWidget);
      expect(find.text('Gunakan Kode Contoh (RT 05)'), findsOneWidget);

      // Tap sample fill
      await tester.tap(find.text('Gunakan Kode Contoh (RT 05)'));
      await tester.pumpAndSettle();

      // Proceed to Step 1
      await tester.ensureVisible(find.text('Lanjutkan ke Verifikasi HP →'));
      await tester.tap(find.text('Lanjutkan ke Verifikasi HP →'));
      await tester.pumpAndSettle();

      expect(find.text('Verifikasi WhatsApp'), findsOneWidget);
      expect(find.text('NOMOR WHATSAPP'), findsOneWidget);
      expect(find.text('KODE VERIFIKASI (6 DIGIT)'), findsOneWidget);

      // Proceed to Step 2
      await tester.ensureVisible(find.text('Verifikasi OTP →'));
      await tester.tap(find.text('Verifikasi OTP →'));
      await tester.pumpAndSettle();

      expect(find.text('Izin Komunikasi Darurat'), findsOneWidget);
      expect(find.text('Bluetooth & Perangkat Sekitar (Relay BLE)'), findsOneWidget);
      expect(find.text('Lokasi & GPS Presisi'), findsOneWidget);
      expect(find.text('Pemberitahuan Sirine Darurat'), findsOneWidget);
      expect(find.text('Selesai & Masuk Aplikasi Warga'), findsOneWidget);
    });
  });

  group('HomePage Condition Tests (Normal vs Drill vs Real Emergency)', () {
    testWidgets('HomePage Normal State (No Siaga): Renders calm deck and preparedness score', (tester) async {
      await tester.binding.setSurfaceSize(phoneStandard);
      final normalState = WargaState(isNormalState: true);

      await tester.pumpWidget(createTestWidget(
        initialState: normalState,
        child: const HomePage(),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Kondisi RT Aman & Terkendali'), findsOneWidget);
      expect(find.text('Kesiapsiagaan Mandiri'), findsOneWidget);
      expect(find.text('Panduan P3K'), findsOneWidget);
      expect(find.text('Tas Siaga 72 Jam'), findsOneWidget);
      expect(find.text('Titik Kumpul'), findsOneWidget);
      expect(find.text('Rumah Saya'), findsOneWidget);

      // Verify emergency buttons are NOT shown during normal calm state
      expect(find.text('Aman di Rumah'), findsNothing);
      expect(find.text('Di Titik Kumpul'), findsNothing);
    });

    testWidgets('HomePage Drill State: Shows TrainingBanner and 3 emergency action buttons', (tester) async {
      await tester.binding.setSurfaceSize(phoneStandard);
      final drillState = WargaState(
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

      await tester.pumpWidget(createTestWidget(
        initialState: drillState,
        child: const HomePage(),
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('LATIHAN'), findsWidgets);
      expect(find.text('Aman di Rumah'), findsOneWidget);
      expect(find.text('Di Titik Kumpul'), findsOneWidget);
      expect(find.text('Butuh Bantuan'), findsOneWidget);

      // Tap quick report Aman di Rumah
      await tester.tap(find.text('Aman di Rumah'));
      await tester.pump();
      expect(find.byType(SnackBar), findsOneWidget);
    });

    testWidgets('HomePage Real Emergency State: Shows crimson real alert banner and 3 buttons', (tester) async {
      await tester.binding.setSurfaceSize(phoneStandard);
      final realEmergencyState = WargaState(
        activeIncident: Incident(
          id: 'inc-real',
          rtId: 'rt-05',
          shortId: 106,
          hazard: HazardType.banjir,
          status: IncidentStatus.aktif,
          mode: IncidentMode.nyata,
          message: 'Banjir Luapan Kali Ciliwung mencapai 1.5 meter. Segera evakuasi ke Balai RW!',
          startedBy: 'Ketua RT 05',
          startedAt: DateTime.now(),
        ),
      );

      await tester.pumpWidget(createTestWidget(
        initialState: realEmergencyState,
        child: const HomePage(),
      ));
      await tester.pumpAndSettle();

      expect(find.text('PERINGATAN RESMI: DARURAT BANJIR'), findsOneWidget);
      expect(find.text('Aman di Rumah'), findsOneWidget);
      expect(find.text('Di Titik Kumpul'), findsOneWidget);
      expect(find.text('Butuh Bantuan'), findsOneWidget);
    });
  });

  group('AnnouncementsPage Viewport Tests', () {
    testWidgets('AnnouncementsPage renders list and filter chips without overflow', (tester) async {
      await tester.binding.setSurfaceSize(phoneSmall);
      await tester.pumpWidget(createTestWidget(
        viewport: phoneSmall,
        child: const AnnouncementsPage(),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Pengumuman Resmi RT'), findsOneWidget);
      expect(find.text('Semua (3)'), findsOneWidget);
      expect(find.text('Darurat'), findsOneWidget);
      expect(find.text('Peringatan'), findsOneWidget);

      // Tap Darurat filter
      await tester.tap(find.text('Darurat'));
      await tester.pumpAndSettle();
      expect(find.text('Instruksi Kesiapsiagaan Siaga 1 Banjir'), findsOneWidget);
    });
  });

  group('HouseholdPage Viewport Tests', () {
    testWidgets('HouseholdPage renders family directory and privacy switch without overflow', (tester) async {
      await tester.binding.setSurfaceSize(phoneSmall);
      await tester.pumpWidget(createTestWidget(
        viewport: phoneSmall,
        child: const HouseholdPage(),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Data Rumah & Keluarga'), findsOneWidget);
      expect(find.textContaining('Rumah No. 04'), findsOneWidget);
      expect(find.text('Santoso'), findsOneWidget);
      expect(find.text('Budi Santoso (Lansia Tirah Baring)'), findsOneWidget);
      expect(find.text('BUTUH BANTUAN TANDU'), findsOneWidget);
      expect(find.text('Rencana Evakuasi Mandiri'), findsOneWidget);
      expect(find.text('Persetujuan Data Kerentanan & Medis'), findsOneWidget);
    });
  });

  group('SettingsPage Viewport Tests', () {
    testWidgets('SettingsPage renders battery, beacon, and simulation deck without overflow', (tester) async {
      await tester.binding.setSurfaceSize(phoneStandard);
      await tester.pumpWidget(createTestWidget(
        viewport: phoneStandard,
        child: const SettingsPage(),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Pengaturan & Simulasi'), findsOneWidget);
      expect(find.text('Mode Hemat Baterai Darurat'), findsOneWidget);
      expect(find.text('Check-in Otomatis di Titik Kumpul'), findsOneWidget);

      // Scroll to reveal simulation deck
      await tester.scrollUntilVisible(find.text('Status Mode Siaga Bencana'), 200);
      await tester.pumpAndSettle();

      expect(find.text('Status Mode Siaga Bencana'), findsOneWidget);
      expect(find.text('Tipe Bencana yang Aktif'), findsOneWidget);

      await tester.scrollUntilVisible(find.text('Keluar dari Akun Rumah Tangga'), 200);
      await tester.pumpAndSettle();
      expect(find.text('Keluar dari Akun Rumah Tangga'), findsOneWidget);
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
      testWidgets('HomePage renders with zero overflow on ${entry.key}', (tester) async {
        await tester.binding.setSurfaceSize(entry.value);
        await tester.pumpWidget(createTestWidget(
          viewport: entry.value,
          child: const HomePage(),
        ));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });

      testWidgets('HouseholdPage renders with zero overflow on ${entry.key}', (tester) async {
        await tester.binding.setSurfaceSize(entry.value);
        await tester.pumpWidget(createTestWidget(
          viewport: entry.value,
          child: const HouseholdPage(),
        ));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });

      testWidgets('AnnouncementsPage renders with zero overflow on ${entry.key}', (tester) async {
        await tester.binding.setSurfaceSize(entry.value);
        await tester.pumpWidget(createTestWidget(
          viewport: entry.value,
          child: const AnnouncementsPage(),
        ));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });

      testWidgets('SettingsPage renders with zero overflow on ${entry.key}', (tester) async {
        await tester.binding.setSurfaceSize(entry.value);
        await tester.pumpWidget(createTestWidget(
          viewport: entry.value,
          child: const SettingsPage(),
        ));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });

      testWidgets('OnboardingPage renders with zero overflow on ${entry.key}', (tester) async {
        await tester.binding.setSurfaceSize(entry.value);
        await tester.pumpWidget(createTestWidget(
          viewport: entry.value,
          child: const OnboardingPage(),
        ));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });

      testWidgets('EducationPage renders with zero overflow on ${entry.key}', (tester) async {
        await tester.binding.setSurfaceSize(entry.value);
        await tester.pumpWidget(createTestWidget(
          viewport: entry.value,
          child: const EducationPage(),
        ));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });

      testWidgets('FirstAidPage renders with zero overflow on ${entry.key}', (tester) async {
        await tester.binding.setSurfaceSize(entry.value);
        await tester.pumpWidget(createTestWidget(
          viewport: entry.value,
          child: const FirstAidPage(),
        ));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  });
}

class _MockWargaNotifier extends WargaNotifier {
  _MockWargaNotifier(WargaState initialState) {
    state = initialState;
  }
}
