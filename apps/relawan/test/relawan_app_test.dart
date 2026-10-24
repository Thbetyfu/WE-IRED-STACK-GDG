import 'package:flutter_test/flutter_test.dart';
import 'package:core/core.dart';
import 'package:relawan/app/relawan_state.dart';

void main() {
  group('RelawanState and RelawanNotifier Unit Tests', () {
    test('Initial RelawanState defaults are initialized correctly', () {
      final state = RelawanState();
      expect(state.volunteerName, 'Budi Santoso');
      expect(state.assignedBlock, 'Blok A');
      expect(state.tasks.length, 3);
      expect(state.isCollectorScanning, isTrue);
      expect(state.collectedPacketsCount, 14);
    });

    test('Updating task status transitions task properly', () {
      final notifier = RelawanNotifier();
      notifier.updateTaskStatus('tsk-01', 'menuju_lokasi', notes: 'Membawa tandu');
      final updated = notifier.state.tasks.firstWhere((t) => t.id == 'tsk-01');
      expect(updated.status, 'menuju_lokasi');
      expect(updated.outreachNotes, 'Membawa tandu');
    });

    test('Overdue logic accurately identifies tasks exceeding 5 minutes', () {
      final task = VolunteerTask(
        id: 'tsk-test',
        householdId: 'hh-01',
        householdNumber: '01',
        headName: 'Test Family',
        address: 'Jl. Merak',
        block: 'Blok A',
        priorityScore: 70.0,
        urgency: ReportUrgency.kritis,
        needs: ['Evakuasi'],
        status: 'diterima',
        assignedAt: DateTime.now().subtract(const Duration(minutes: 6)),
      );
      expect(task.isOverdue, isTrue);
    });

    test('Completed tasks are never overdue', () {
      final task = VolunteerTask(
        id: 'tsk-done',
        householdId: 'hh-01',
        householdNumber: '01',
        headName: 'Test Family',
        address: 'Jl. Merak',
        block: 'Blok A',
        priorityScore: 70.0,
        urgency: ReportUrgency.kritis,
        needs: ['Evakuasi'],
        status: 'selesai',
        assignedAt: DateTime.now().subtract(const Duration(minutes: 20)),
      );
      expect(task.isOverdue, isFalse);
    });

    test('Proxy report submission queues packet and increases count', () {
      final notifier = RelawanNotifier();
      final initialCount = notifier.state.collectedPacketsCount;
      notifier.submitProxyReport(
        householdId: 'hh-09',
        householdNumber: '09',
        status: ReportStatus.butuhBantuan,
        urgency: ReportUrgency.biasa,
        needs: ['Makanan / Logistik'],
        notes: 'Warga lansia butuh air mineral',
      );
      expect(notifier.state.collectedPacketsCount, initialCount + 1);
    });

    test('Posko packet sync resets packet buffer count', () {
      final notifier = RelawanNotifier();
      expect(notifier.state.collectedPacketsCount, greaterThan(0));
      notifier.syncCollectedPackets();
      expect(notifier.state.collectedPacketsCount, 0);
      expect(notifier.state.lastSyncTime, isNotNull);
    });
  });
}
