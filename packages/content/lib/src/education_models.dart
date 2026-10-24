class QuizChoice {
  final String id;
  final String text;
  final bool isCorrect;
  final String explanation;

  const QuizChoice({
    required this.id,
    required this.text,
    required this.isCorrect,
    required this.explanation,
  });
}

class QuizQuestion {
  final String id;
  final String question;
  final List<QuizChoice> choices;

  const QuizQuestion({
    required this.id,
    required this.question,
    required this.choices,
  });
}

class EducationModule {
  final String id;
  final String title;
  final String disasterType; // 'banjir', 'gempa', 'longsor', 'kebakaran'
  final int estimatedMinutes;
  final String summary;
  final List<String> bulletPoints;
  final List<QuizQuestion> quiz;
  final String officialSource;

  const EducationModule({
    required this.id,
    required this.title,
    required this.disasterType,
    required this.estimatedMinutes,
    required this.summary,
    required this.bulletPoints,
    required this.quiz,
    required this.officialSource,
  });
}

class EmergencyBagItem {
  final String id;
  final String name;
  final String category; // 'dokumen', 'p3k', 'pangan', 'sandang', 'alat'
  final String description;
  final bool isEssential;

  const EmergencyBagItem({
    required this.id,
    required this.name,
    required this.category,
    required this.description,
    this.isEssential = true,
  });
}
