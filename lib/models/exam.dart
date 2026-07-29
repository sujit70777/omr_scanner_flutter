import 'dart:convert';
import 'dart:ui' show Offset;

/// A quadrilateral region of bubbles for a contiguous block of questions.
/// Corners are centers of the extreme bubbles, in ORIGINAL image pixels:
///   topLeft     = Question[startQ], Option[0]
///   topRight    = Question[startQ], Option[optionsCount-1]
///   bottomRight = Question[endQ],   Option[optionsCount-1]
///   bottomLeft  = Question[endQ],   Option[0]
/// Storing all 4 corners (instead of just 2 opposite ones) lets bubble
/// positions be found by bilinear interpolation across the quad, which
/// stays accurate even when the photo is mildly rotated, tilted, or has
/// keystone distortion — a plain 2-point rectangle breaks under any of those.
class CalibrationSection {
  final int startQ;
  final int endQ;
  final Offset topLeft;
  final Offset topRight;
  final Offset bottomRight;
  final Offset bottomLeft;

  CalibrationSection({
    required this.startQ,
    required this.endQ,
    required this.topLeft,
    required this.topRight,
    required this.bottomRight,
    required this.bottomLeft,
  });

  /// Bilinear-interpolated pixel position for row t (0=first question, 1=last)
  /// and col s (0=first option, 1=last option).
  Offset pointAt(double t, double s) {
    final top = Offset.lerp(topLeft, topRight, s)!;
    final bottom = Offset.lerp(bottomLeft, bottomRight, s)!;
    return Offset.lerp(top, bottom, t)!;
  }

  Map<String, dynamic> toJson() => {
        'startQ': startQ,
        'endQ': endQ,
        'tlx': topLeft.dx, 'tly': topLeft.dy,
        'trx': topRight.dx, 'try': topRight.dy,
        'brx': bottomRight.dx, 'bry': bottomRight.dy,
        'blx': bottomLeft.dx, 'bly': bottomLeft.dy,
      };

  factory CalibrationSection.fromJson(Map<String, dynamic> j) {
    // Back-compat: older calibrations only stored 2 opposite corners
    // (tlx/tly + brx/bry). Reconstruct an axis-aligned quad from those.
    final hasFullQuad = j.containsKey('trx');
    if (!hasFullQuad) {
      final tl = Offset((j['tlx'] as num).toDouble(), (j['tly'] as num).toDouble());
      final br = Offset((j['brx'] as num).toDouble(), (j['bry'] as num).toDouble());
      return CalibrationSection(
        startQ: j['startQ'],
        endQ: j['endQ'],
        topLeft: tl,
        topRight: Offset(br.dx, tl.dy),
        bottomRight: br,
        bottomLeft: Offset(tl.dx, br.dy),
      );
    }
    return CalibrationSection(
      startQ: j['startQ'],
      endQ: j['endQ'],
      topLeft: Offset((j['tlx'] as num).toDouble(), (j['tly'] as num).toDouble()),
      topRight: Offset((j['trx'] as num).toDouble(), (j['try'] as num).toDouble()),
      bottomRight: Offset((j['brx'] as num).toDouble(), (j['bry'] as num).toDouble()),
      bottomLeft: Offset((j['blx'] as num).toDouble(), (j['bly'] as num).toDouble()),
    );
  }
}


class Exam {
  final int? id;
  final String name;
  final int totalQuestions;
  final int optionsCount; // usually 4 (ক খ গ ঘ)
  final String createdAt;
  final Map<int, List<int>> answerKey; // questionNo -> correct option indices (supports multi-answer)
  final List<CalibrationSection> calibration; // empty until calibrated
  final double? sheetAspectRatio; // width/height of the calibration sample photo, guides live scan overlay

  Exam({
    this.id,
    required this.name,
    required this.totalQuestions,
    this.optionsCount = 4,
    required this.createdAt,
    Map<int, List<int>>? answerKey,
    List<CalibrationSection>? calibration,
    this.sheetAspectRatio,
  })  : answerKey = answerKey ?? {},
        calibration = calibration ?? [];

  bool get hasAnswerKey => answerKey.length == totalQuestions && answerKey.values.every((v) => v.isNotEmpty);

  /// Kept only so old saved rows still load. The scanner no longer uses
  /// calibration — it registers against the sheet's own printed marks.
  bool get isCalibrated => true;

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'totalQuestions': totalQuestions,
        'optionsCount': optionsCount,
        'createdAt': createdAt,
        'answerKeyJson': jsonEncode(answerKey.map((k, v) => MapEntry(k.toString(), v))),
        'calibrationJson': jsonEncode(calibration.map((c) => c.toJson()).toList()),
        'sheetAspectRatio': sheetAspectRatio,
      };

  factory Exam.fromMap(Map<String, dynamic> m) {
    final akRaw = jsonDecode(m['answerKeyJson'] ?? '{}') as Map<String, dynamic>;
    final ak = <int, List<int>>{};
    akRaw.forEach((k, v) => ak[int.parse(k)] = List<int>.from(v));
    final calRaw = jsonDecode(m['calibrationJson'] ?? '[]') as List<dynamic>;
    final cal = calRaw.map((c) => CalibrationSection.fromJson(c)).toList();
    return Exam(
      id: m['id'],
      name: m['name'],
      totalQuestions: m['totalQuestions'],
      optionsCount: m['optionsCount'] ?? 4,
      createdAt: m['createdAt'],
      answerKey: ak,
      calibration: cal,
      sheetAspectRatio: (m['sheetAspectRatio'] as num?)?.toDouble(),
    );
  }

  Exam copyWith({
    String? name,
    int? totalQuestions,
    int? optionsCount,
    Map<int, List<int>>? answerKey,
    List<CalibrationSection>? calibration,
    double? sheetAspectRatio,
  }) {
    return Exam(
      id: id,
      name: name ?? this.name,
      totalQuestions: totalQuestions ?? this.totalQuestions,
      optionsCount: optionsCount ?? this.optionsCount,
      createdAt: createdAt,
      answerKey: answerKey ?? this.answerKey,
      calibration: calibration ?? this.calibration,
      sheetAspectRatio: sheetAspectRatio ?? this.sheetAspectRatio,
    );
  }
}

const List<String> optionLabelsBn = ['ক', 'খ', 'গ', 'ঘ', 'ঙ'];
const List<String> optionLabelsEn = ['A', 'B', 'C', 'D', 'E'];
