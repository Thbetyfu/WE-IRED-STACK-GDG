import 'package:test/test.dart';
import 'package:core/core.dart';

void main() {
  group('SDD Models Test', () {
    test('AppError JSON matches SDD 9.7 structure', () {
      final json = {
        'error': {
          'code': 'VALIDATION_FAILED',
          'message': 'Nomor WhatsApp tidak valid',
          'details': {'field': 'wa_phone'}
        }
      };

      final error = AppError.fromJson(json);
      expect(error.code, 'VALIDATION_FAILED');
      expect(error.message, 'Nomor WhatsApp tidak valid');
      expect(error.details?['field'], 'wa_phone');

      final serialized = error.toJson();
      expect(serialized['error']['code'], 'VALIDATION_FAILED');
    });

    test('Member vulnerability flags calculation (SDD 5.2)', () {
      // Bit 0: lansia (1), Bit 3: balita (8) -> 1 | 8 = 9
      final member = Member(
        id: 'mem-1',
        householdId: 'hh-1',
        idx: 0,
        name: 'Mbah Kardi',
        birthYear: 1946,
        sex: 'L',
        relation: 'kepala',
        vulnFlags: (1 << 0) | (1 << 3),
      );

      expect(member.isElderly, isTrue);
      expect(member.isToddler, isTrue);
      expect(member.hasDisability, isFalse);
      expect(member.isPregnant, isFalse);
      expect(member.isVulnerable, isTrue);
    });

    test('Report and HouseholdState serialization', () {
      final now = DateTime.now();
      final report = Report(
        id: 'rep-1',
        incidentId: 'inc-1',
        householdId: 'hh-1',
        seq: 1,
        status: ReportStatus.butuhBantuan,
        urgency: ReportUrgency.kritis,
        needs: ReportNeeds.evakuasi | ReportNeeds.medis,
        channel: 'app',
        deviceTime: now,
      );

      expect(report.isCritical, isTrue);
      expect(ReportNeeds.hasNeed(report.needs, ReportNeeds.evakuasi), isTrue);
      expect(ReportNeeds.hasNeed(report.needs, ReportNeeds.medis), isTrue);
      expect(ReportNeeds.hasNeed(report.needs, ReportNeeds.logistik), isFalse);

      final json = report.toJson();
      final deserialized = Report.fromJson(json);
      expect(deserialized.id, report.id);
      expect(deserialized.seq, 1);
      expect(deserialized.urgency, ReportUrgency.kritis);
    });

    test('Incident and TaskItem status mappings', () {
      final incident = Incident(
        id: 'inc-1',
        rtId: 'rt-01',
        shortId: 101,
        hazard: HazardType.banjir,
        mode: IncidentMode.latihan,
        message: 'Simulasi evakuasi banjir',
        startedBy: 'user-admin',
        startedAt: DateTime.now(),
      );

      expect(incident.isDrill, isTrue);
      expect(incident.isActive, isTrue);

      final task = TaskItem(
        id: 'tsk-1',
        incidentId: incident.id,
        householdId: 'hh-1',
        status: TaskStatus.dalamPerjalanan,
        createdBy: 'user-admin',
        createdAt: DateTime.now(),
      );

      expect(task.status.toDbString(), 'dalam_perjalanan');
    });
  });
}
