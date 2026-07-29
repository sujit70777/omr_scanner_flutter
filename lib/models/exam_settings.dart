/// Per-exam grading / scoring rules.
class ExamSettings {
  /// Student filled extra bubbles beyond the key. If the correct answer(s)
  /// are also filled, count as correct when true; otherwise mark wrong.
  final bool multiMarkCountsIfIncludesAnswer;

  /// Key has multiple correct options and the student did not fill all of
  /// them. Count as correct when true (at least one correct, no wrong
  /// options unless [multiMarkCountsIfIncludesAnswer] also allows extras);
  /// otherwise require every correct option to be filled.
  final bool partialMultiAnswerCounts;

  /// Marks awarded per correct question.
  final double marksPerCorrect;

  /// Marks deducted per wrong (attempted but incorrect) question. 0 = off.
  final double negativeMarkPerWrong;

  /// If true, blank questions are treated as wrong for the wrong-count
  /// (and take negative marks if set). Otherwise they stay "unattempted".
  final bool countBlankAsWrong;

  const ExamSettings({
    this.multiMarkCountsIfIncludesAnswer = false,
    this.partialMultiAnswerCounts = false,
    this.marksPerCorrect = 1.0,
    this.negativeMarkPerWrong = 0.0,
    this.countBlankAsWrong = false,
  });

  Map<String, dynamic> toJson() => {
        'multiMarkCountsIfIncludesAnswer': multiMarkCountsIfIncludesAnswer,
        'partialMultiAnswerCounts': partialMultiAnswerCounts,
        'marksPerCorrect': marksPerCorrect,
        'negativeMarkPerWrong': negativeMarkPerWrong,
        'countBlankAsWrong': countBlankAsWrong,
      };

  factory ExamSettings.fromJson(Map<String, dynamic>? j) {
    if (j == null || j.isEmpty) return const ExamSettings();
    return ExamSettings(
      multiMarkCountsIfIncludesAnswer: j['multiMarkCountsIfIncludesAnswer'] as bool? ?? false,
      partialMultiAnswerCounts: j['partialMultiAnswerCounts'] as bool? ?? false,
      marksPerCorrect: (j['marksPerCorrect'] as num?)?.toDouble() ?? 1.0,
      negativeMarkPerWrong: (j['negativeMarkPerWrong'] as num?)?.toDouble() ?? 0.0,
      countBlankAsWrong: j['countBlankAsWrong'] as bool? ?? false,
    );
  }

  ExamSettings copyWith({
    bool? multiMarkCountsIfIncludesAnswer,
    bool? partialMultiAnswerCounts,
    double? marksPerCorrect,
    double? negativeMarkPerWrong,
    bool? countBlankAsWrong,
  }) {
    return ExamSettings(
      multiMarkCountsIfIncludesAnswer:
          multiMarkCountsIfIncludesAnswer ?? this.multiMarkCountsIfIncludesAnswer,
      partialMultiAnswerCounts: partialMultiAnswerCounts ?? this.partialMultiAnswerCounts,
      marksPerCorrect: marksPerCorrect ?? this.marksPerCorrect,
      negativeMarkPerWrong: negativeMarkPerWrong ?? this.negativeMarkPerWrong,
      countBlankAsWrong: countBlankAsWrong ?? this.countBlankAsWrong,
    );
  }
}
