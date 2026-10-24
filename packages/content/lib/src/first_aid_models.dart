/// Step-by-step emergency action in a First Aid guide
class FirstAidStep {
  final int stepNumber;
  final String title;
  final String instruction;
  final String? warning;

  const FirstAidStep({
    required this.stepNumber,
    required this.title,
    required this.instruction,
    this.warning,
  });
}

/// Comprehensive offline First Aid guide per FR-FA-01..03
class FirstAidGuide {
  final String id;
  final String title;
  final String subtitle;
  final String iconName;
  final String urgencyLevel; // 'kritis', 'tinggi', 'sedang'
  final List<String> dangerSigns;
  final List<FirstAidStep> steps;
  final List<String> thingsToAvoid;
  final String sourceAttribution;
  final String medicalDisclaimer;

  const FirstAidGuide({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.iconName,
    required this.urgencyLevel,
    required this.dangerSigns,
    required this.steps,
    required this.thingsToAvoid,
    required this.sourceAttribution,
    this.medicalDisclaimer = 'Panduan ini adalah tindakan pertolongan pertama sementara sampai bantuan medis tiba. Segera hubungi petugas medis atau posko evakuasi terdekat.',
  });
}
