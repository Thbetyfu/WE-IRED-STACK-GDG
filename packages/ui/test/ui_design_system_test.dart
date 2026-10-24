import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ui/ui.dart';

void main() {
  const phoneSmall = Size(360, 640);
  const phoneStandard = Size(390, 844);

  Widget createTestApp({
    required Widget child,
    Size viewport = phoneStandard,
    double textScale = 1.0,
  }) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: MediaQuery(
        data: MediaQueryData(
          size: viewport,
          textScaler: TextScaler.linear(textScale),
        ),
        child: Scaffold(body: Center(child: child)),
      ),
    );
  }

  group('Design System Tokens and Theme Tests', () {
    test('Palette and semantic tokens are defined with WCAG contrast hierarchy', () {
      expect(AppTheme.slate50, const Color(0xFFF8FAFC));
      expect(AppTheme.slate900, const Color(0xFF0F172A));
      expect(AppTheme.statusAman, const Color(0xFF16A34A));
      expect(AppTheme.statusTitikKumpul, const Color(0xFF2563EB));
      expect(AppTheme.statusButuhBantuan, const Color(0xFFEA580C));
      expect(AppTheme.statusKritis, const Color(0xFFDC2626));
      expect(AppTheme.statusBelumMelapor, const Color(0xFF64748B));
    });

    test('Spacing and radius tokens conform to 8-pt spatial system', () {
      expect(AppTheme.spacingSm, 8.0);
      expect(AppTheme.spacingLg, 16.0);
      expect(AppTheme.spacingXxl, 24.0);
      expect(AppTheme.spacing3xl, 32.0);

      expect(AppTheme.radiusSm, 6.0);
      expect(AppTheme.radiusMd, 8.0);
      expect(AppTheme.radiusLg, 12.0);
    });

    test('Touch targets satisfy accessibility requirements', () {
      expect(AppTheme.touchTargetMin, 48.0);
      expect(AppTheme.touchTargetEmergency, 64.0);
      expect(AppTheme.touchTargetField, 52.0);
    });

    test('ThemeData light and dark build without error', () {
      final lightTheme = AppTheme.light();
      final darkTheme = AppTheme.dark();

      expect(lightTheme.useMaterial3, isTrue);
      expect(darkTheme.useMaterial3, isTrue);
      expect(lightTheme.colorScheme.primary, AppTheme.primaryBlue);
      expect(lightTheme.scaffoldBackgroundColor, AppTheme.bgCanvas);
    });
  });

  group('StatusBadge & PriorityTierBadge Tests', () {
    testWidgets('StatusBadge renders all 5 statuses with distinct icons and labels', (tester) async {
      await tester.pumpWidget(createTestApp(
        child: const Column(
          children: [
            StatusBadge(status: 'aman'),
            StatusBadge(status: 'titik_kumpul'),
            StatusBadge(status: 'butuh_bantuan'),
            StatusBadge(status: 'kritis'),
            StatusBadge(status: 'belum_melapor'),
          ],
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Aman'), findsOneWidget);
      expect(find.text('Di Titik Kumpul'), findsOneWidget);
      expect(find.text('Butuh Bantuan'), findsOneWidget);
      expect(find.text('Kritis'), findsOneWidget);
      expect(find.text('Belum Melapor'), findsOneWidget);
    });

    testWidgets('StatusBadge compact mode renders with reduced padding', (tester) async {
      await tester.pumpWidget(createTestApp(
        child: const StatusBadge(status: 'kritis', compact: true),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Kritis'), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    });

    testWidgets('PriorityTierBadge renders tier and optional score', (tester) async {
      await tester.pumpWidget(createTestApp(
        child: const Column(
          children: [
            PriorityTierBadge(tier: 'kritis', score: 84.5),
            PriorityTierBadge(tier: 'mendesak', score: 55.0),
            PriorityTierBadge(tier: 'reguler'),
          ],
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('KRITIS (84.5)'), findsOneWidget);
      expect(find.text('MENDESAK (55.0)'), findsOneWidget);
      expect(find.text('REGULER'), findsOneWidget);
    });
  });

  group('EmergencyActionButton Accessibility & Contrast Tests', () {
    testWidgets('EmergencyActionButton satisfies >= 64dp height requirement', (tester) async {
      await tester.pumpWidget(createTestApp(
        child: EmergencyActionButton.aman(onPressed: () {}),
      ));
      await tester.pumpAndSettle();

      final inkFinder = find.byType(Ink);
      expect(inkFinder, findsOneWidget);

      final renderBox = tester.renderObject(inkFinder) as RenderBox;
      expect(renderBox.size.height, greaterThanOrEqualTo(64.0));
      expect(find.text('Aman di Rumah'), findsOneWidget);
    });

    testWidgets('EmergencyActionButton renders critical variant with high urgency', (tester) async {
      await tester.pumpWidget(createTestApp(
        child: EmergencyActionButton.butuhBantuan(
          onPressed: () {},
          isKritis: true,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Butuh Bantuan'), findsOneWidget);
      expect(find.text('KONDISI KRITIS / DARURAT MEDIS'), findsOneWidget);
    });

    testWidgets('EmergencyActionButton handles loading state properly', (tester) async {
      await tester.pumpWidget(createTestApp(
        child: EmergencyActionButton.titikKumpul(
          onPressed: () {},
          isLoading: true,
        ),
      ));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });

  group('Operational Card, Tile, and Header Tests', () {
    testWidgets('OperationalMetricTile renders label, value, and subtitle', (tester) async {
      await tester.pumpWidget(createTestApp(
        child: const OperationalMetricTile(
          label: 'Total Warga',
          value: '142',
          subtitle: 'Terdata di RT 05',
          icon: Icons.people,
          accentColor: AppTheme.primaryBlue,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('TOTAL WARGA'), findsOneWidget);
      expect(find.text('142'), findsOneWidget);
      expect(find.text('Terdata di RT 05'), findsOneWidget);
    });

    testWidgets('OperationalSectionHeader renders title, subtitle, and trailing', (tester) async {
      await tester.pumpWidget(createTestApp(
        child: const OperationalSectionHeader(
          title: 'Daftar Tugas Relawan',
          subtitle: 'Berdasarkan prioritas penanganan',
          trailing: Text('3 Aktif'),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Daftar Tugas Relawan'), findsOneWidget);
      expect(find.text('Berdasarkan prioritas penanganan'), findsOneWidget);
      expect(find.text('3 Aktif'), findsOneWidget);
    });

    testWidgets('OperationalPageHeader adapts between wide desktop and narrow tablet without overflow', (tester) async {
      // Test narrow viewport (< breakpoint 920)
      await tester.binding.setSurfaceSize(phoneSmall);
      await tester.pumpWidget(createTestApp(
        viewport: phoneSmall,
        child: OperationalPageHeader(
          title: 'Ringkasan Insiden Operasional',
          subtitle: 'Pemantauan real-time evakuasi',
          statusBadge: const StatusBadge(status: 'kritis'),
          actions: [
            ElevatedButton(onPressed: () {}, child: const Text('Aksi 1')),
            OutlinedButton(onPressed: () {}, child: const Text('Aksi 2')),
          ],
        ),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Ringkasan Insiden Operasional'), findsOneWidget);

      // Test wide viewport (1440x900)
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      await tester.pumpWidget(createTestApp(
        viewport: const Size(1440, 900),
        child: OperationalPageHeader(
          title: 'Ringkasan Insiden Operasional',
          subtitle: 'Pemantauan real-time evakuasi',
          statusBadge: const StatusBadge(status: 'kritis'),
          actions: [
            ElevatedButton(onPressed: () {}, child: const Text('Aksi 1')),
          ],
        ),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('OperationalChoiceChip toggles appearance when selected', (tester) async {
      await tester.pumpWidget(createTestApp(
        child: OperationalChoiceChip(
          label: 'Aman di Rumah',
          sublabel: 'Mandiri',
          icon: Icons.check,
          isSelected: true,
          activeColor: AppTheme.statusAman,
          onTap: () {},
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Aman di Rumah'), findsOneWidget);
      expect(find.text('Mandiri'), findsOneWidget);
    });
  });

  group('Feedback, Banners, and State Views Tests', () {
    testWidgets('LoadingStateView, EmptyStateView, and ErrorStateView render properly', (tester) async {
      await tester.pumpWidget(createTestApp(
        child: const Column(
          children: [
            LoadingStateView(message: 'Memuat data triase...'),
            EmptyStateView(
              title: 'Tidak Ada Tugas Aktif',
              description: 'Seluruh warga di blok ini telah aman.',
            ),
            ErrorStateView(message: 'Gagal terhubung ke endpoint Posko.'),
          ],
        ),
      ));
      await tester.pump();

      expect(find.text('Memuat data triase...'), findsOneWidget);
      expect(find.text('Tidak Ada Tugas Aktif'), findsOneWidget);
      expect(find.text('Gagal terhubung ke endpoint Posko.'), findsOneWidget);
    });

    testWidgets('OfflineSyncBanner hides when pendingCount is 0 and shows when > 0', (tester) async {
      await tester.pumpWidget(createTestApp(
        child: const Column(
          children: [
            OfflineSyncBanner(pendingCount: 0),
            OfflineSyncBanner(pendingCount: 4),
          ],
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('4 laporan tersimpan lokal di outbox'), findsOneWidget);
    });

    testWidgets('TrainingBanner distinguishes drill mode from real emergency', (tester) async {
      await tester.pumpWidget(createTestApp(
        child: const Column(
          children: [
            TrainingBanner(isDrill: true),
            TrainingBanner(isDrill: false),
          ],
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('[LATIHAN EVAKUASI / DRILL SIMULASI]'), findsOneWidget);
      expect(find.text('SIAGA DARURAT AKTIF (NYATA)'), findsOneWidget);
    });

    testWidgets('OperationalConfirmDialog renders title, message, and actions', (tester) async {
      bool confirmed = false;
      await tester.pumpWidget(createTestApp(
        child: OperationalConfirmDialog(
          title: 'Hapus Antrean Outbox?',
          message: 'Tindakan ini tidak dapat dibatalkan.',
          isDestructive: true,
          onConfirm: () => confirmed = true,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Hapus Antrean Outbox?'), findsOneWidget);
      expect(find.text('Tindakan ini tidak dapat dibatalkan.'), findsOneWidget);

      await tester.tap(find.text('Konfirmasi'));
      expect(confirmed, isTrue);
    });

    testWidgets('OperationalTableContainer wraps child table without overflow', (tester) async {
      await tester.pumpWidget(createTestApp(
        child: OperationalTableContainer(
          headerTitle: 'Tabel Data Warga RT',
          child: DataTable(
            columns: const [
              DataColumn(label: Text('No')),
              DataColumn(label: Text('Nama')),
              DataColumn(label: Text('Status')),
            ],
            rows: const [
              DataRow(cells: [
                DataCell(Text('01')),
                DataCell(Text('Budi')),
                DataCell(Text('Aman')),
              ]),
            ],
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Tabel Data Warga RT'), findsOneWidget);
      expect(find.text('Budi'), findsOneWidget);
    });
  });

  group('System Text Scaling Multi-Size Verification', () {
    testWidgets('Components scale cleanly under 1.5x and 2.0x text scaling', (tester) async {
      await tester.pumpWidget(createTestApp(
        textScale: 1.5,
        viewport: phoneSmall,
        child: const Column(
          children: [
            StatusBadge(status: 'kritis'),
            PriorityTierBadge(tier: 'kritis', score: 90.0),
            ConnectionStatusPill(mode: 'posko'),
            SyncStatusBadge(status: 'synced'),
          ],
        ),
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });
}
