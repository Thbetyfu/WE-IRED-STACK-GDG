class Member {
  final String id;
  final String householdId;
  final int idx; // 0–7 for bitmask
  final String name;
  final int birthYear;
  final String sex; // L | P
  final String relation; // kepala, istri, anak, orang_tua, lainnya
  final int vulnFlags; // bit 0: lansia, bit 1: disabilitas, bit 2: ibu hamil, bit 3: balita, bit 4: penyakit kronis
  final String? healthNotesEnc;
  final bool needsEvacAssist;

  const Member({
    required this.id,
    required this.householdId,
    required this.idx,
    required this.name,
    required this.birthYear,
    required this.sex,
    required this.relation,
    this.vulnFlags = 0,
    this.healthNotesEnc,
    this.needsEvacAssist = false,
  });

  // Vulnerability helper flags
  bool get isElderly => (vulnFlags & (1 << 0)) != 0;
  bool get hasDisability => (vulnFlags & (1 << 1)) != 0;
  bool get isPregnant => (vulnFlags & (1 << 2)) != 0;
  bool get isToddler => (vulnFlags & (1 << 3)) != 0;
  bool get hasChronicIllness => (vulnFlags & (1 << 4)) != 0;
  bool get isVulnerable => vulnFlags != 0 || needsEvacAssist;

  factory Member.fromJson(Map<String, dynamic> json) {
    return Member(
      id: json['id'] as String,
      householdId: json['household_id'] as String,
      idx: json['idx'] as int? ?? 0,
      name: json['name'] as String,
      birthYear: json['birth_year'] as int,
      sex: json['sex'] as String,
      relation: json['relation'] as String,
      vulnFlags: json['vuln_flags'] as int? ?? 0,
      healthNotesEnc: json['health_notes_enc'] as String?,
      needsEvacAssist: json['needs_evac_assist'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'household_id': householdId,
      'idx': idx,
      'name': name,
      'birth_year': birthYear,
      'sex': sex,
      'relation': relation,
      'vuln_flags': vulnFlags,
      if (healthNotesEnc != null) 'health_notes_enc': healthNotesEnc,
      'needs_evac_assist': needsEvacAssist,
    };
  }
}
