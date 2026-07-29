import 'dart:convert';

class StudentResult {
  final int? id;
  final int examId;
  final String rollNumber;
  final Map<int, List<int>> marked; // questionNo -> marked option indices (from scan)
  final int correctCount;
  final int wrongCount;
  final int unattemptedCount;
  final double score; // 1 mark per correct question by default
  final String scannedAt;

  StudentResult({
    this.id,
    required this.examId,
    required this.rollNumber,
    required this.marked,
    required this.correctCount,
    required this.wrongCount,
    required this.unattemptedCount,
    required this.score,
    required this.scannedAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'examId': examId,
        'rollNumber': rollNumber,
        'markedJson': jsonEncode(marked.map((k, v) => MapEntry(k.toString(), v))),
        'correctCount': correctCount,
        'wrongCount': wrongCount,
        'unattemptedCount': unattemptedCount,
        'score': score,
        'scannedAt': scannedAt,
      };

  factory StudentResult.fromMap(Map<String, dynamic> m) {
    final raw = jsonDecode(m['markedJson'] ?? '{}') as Map<String, dynamic>;
    final marked = <int, List<int>>{};
    raw.forEach((k, v) => marked[int.parse(k)] = List<int>.from(v));
    return StudentResult(
      id: m['id'],
      examId: m['examId'],
      rollNumber: m['rollNumber'],
      marked: marked,
      correctCount: m['correctCount'],
      wrongCount: m['wrongCount'],
      unattemptedCount: m['unattemptedCount'],
      score: (m['score'] as num).toDouble(),
      scannedAt: m['scannedAt'],
    );
  }
}
