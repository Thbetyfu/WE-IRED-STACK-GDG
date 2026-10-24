import 'package:flutter_test/flutter_test.dart';
import 'package:core/core.dart';
import 'package:warga/app/warga_state.dart';

void main() {
  group('WargaState and WargaNotifier Unit Tests', () {
    test('Initial WargaState has correct household defaults', () {
      final state = WargaState();
      expect(state.householdId, 'hh-04');
      expect(state.householdNumber, '04');
      expect(state.members.length, 3);
      expect(state.isSiaga, isTrue);
      expect(state.isDrill, isTrue);
      expect(state.syncStatus, 'synced');
    });

    test('Preparedness score computes accurately per SDD 6.4 formula', () {
      final state = WargaState(
        checkedBagItemIds: {'doc_waterproof', 'drinking_water'},
        quizScores: {'mod_banjir': 100},
        familyEvacuationRoute: 'Rute evakuasi gang barat',
      );
      final score = state.preparednessScore;
      expect(score, isPositive);
      expect(score, lessThanOrEqualTo(100));
    });

    test('Quick report updates report state correctly', () {
      final notifier = WargaNotifier();
      notifier.submitQuickReport(ReportStatus.aman);
      expect(notifier.state.latestReport, isNotNull);
      expect(notifier.state.latestReport!.status, ReportStatus.aman);
      expect(notifier.state.syncStatus, 'synced');
    });

    test('Help report records urgency and affected members', () {
      final notifier = WargaNotifier();
      notifier.submitHelpReport(
        urgency: ReportUrgency.kritis,
        needs: ['Evakuasi Medis'],
        affectedMemberIds: ['mem-03'],
        notes: 'Butuh tandu untuk kakek',
      );
      expect(notifier.state.latestReport, isNotNull);
      expect(notifier.state.latestReport!.urgency, ReportUrgency.kritis);
      expect(notifier.state.latestReport!.message, 'Butuh tandu untuk kakek');
    });

    test('Drill toggle switches between latihan and nyata', () {
      final notifier = WargaNotifier();
      expect(notifier.state.isDrill, isTrue);
      notifier.toggleDrillMode();
      expect(notifier.state.isDrill, isFalse);
      notifier.toggleDrillMode();
      expect(notifier.state.isDrill, isTrue);
    });

    test('Tas siaga item toggle updates item set', () {
      final notifier = WargaNotifier();
      final initialCount = notifier.state.checkedBagItemIds.length;
      notifier.toggleBagItem('cash_money');
      expect(notifier.state.checkedBagItemIds.length, initialCount + 1);
      notifier.toggleBagItem('cash_money');
      expect(notifier.state.checkedBagItemIds.length, initialCount);
    });
  });
}
