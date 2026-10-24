enum TaskStatus {
  disarankan,
  ditugaskan,
  diterima,
  dalamPerjalanan,
  dijangkau,
  selesai,
  ditolak;

  static TaskStatus fromString(String str) {
    switch (str.toLowerCase()) {
      case 'disarankan':
        return TaskStatus.disarankan;
      case 'ditugaskan':
        return TaskStatus.ditugaskan;
      case 'diterima':
        return TaskStatus.diterima;
      case 'dalam_perjalanan':
      case 'dalamperjalanan':
        return TaskStatus.dalamPerjalanan;
      case 'dijangkau':
        return TaskStatus.dijangkau;
      case 'selesai':
        return TaskStatus.selesai;
      case 'ditolak':
        return TaskStatus.ditolak;
      default:
        return TaskStatus.disarankan;
    }
  }

  String toDbString() {
    switch (this) {
      case TaskStatus.disarankan:
        return 'disarankan';
      case TaskStatus.ditugaskan:
        return 'ditugaskan';
      case TaskStatus.diterima:
        return 'diterima';
      case TaskStatus.dalamPerjalanan:
        return 'dalam_perjalanan';
      case TaskStatus.dijangkau:
        return 'dijangkau';
      case TaskStatus.selesai:
        return 'selesai';
      case TaskStatus.ditolak:
        return 'ditolak';
    }
  }
}

class TaskItem {
  final String id;
  final String incidentId;
  final String householdId;
  final String? volunteerId;
  final TaskStatus status;
  final String? outcome; // aman_di_tempat | dievakuasi | dirujuk | butuh_lanjutan
  final String? rejectReason;
  final String createdBy;
  final DateTime createdAt;
  final DateTime? assignedAt;
  final DateTime? acceptedAt;
  final DateTime? reachedAt;
  final DateTime? completedAt;

  const TaskItem({
    required this.id,
    required this.incidentId,
    required this.householdId,
    this.volunteerId,
    required this.status,
    this.outcome,
    this.rejectReason,
    required this.createdBy,
    required this.createdAt,
    this.assignedAt,
    this.acceptedAt,
    this.reachedAt,
    this.completedAt,
  });

  factory TaskItem.fromJson(Map<String, dynamic> json) {
    return TaskItem(
      id: json['id'] as String,
      incidentId: json['incident_id'] as String,
      householdId: json['household_id'] as String,
      volunteerId: json['volunteer_id'] as String?,
      status: TaskStatus.fromString(json['status'] as String),
      outcome: json['outcome'] as String?,
      rejectReason: json['reject_reason'] as String?,
      createdBy: json['created_by'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      assignedAt: json['assigned_at'] != null ? DateTime.parse(json['assigned_at'] as String) : null,
      acceptedAt: json['accepted_at'] != null ? DateTime.parse(json['accepted_at'] as String) : null,
      reachedAt: json['reached_at'] != null ? DateTime.parse(json['reached_at'] as String) : null,
      completedAt: json['completed_at'] != null ? DateTime.parse(json['completed_at'] as String) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'incident_id': incidentId,
      'household_id': householdId,
      if (volunteerId != null) 'volunteer_id': volunteerId,
      'status': status.toDbString(),
      if (outcome != null) 'outcome': outcome,
      if (rejectReason != null) 'reject_reason': rejectReason,
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
      if (assignedAt != null) 'assigned_at': assignedAt!.toIso8601String(),
      if (acceptedAt != null) 'accepted_at': acceptedAt!.toIso8601String(),
      if (reachedAt != null) 'reached_at': reachedAt!.toIso8601String(),
      if (completedAt != null) 'completed_at': completedAt!.toIso8601String(),
    };
  }
}
