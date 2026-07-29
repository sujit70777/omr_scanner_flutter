import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import '../models/exam.dart';
import 'sheet_template.dart';

class BubbleReading {
  final int question;
  final int option;
  final double fillRatio;
  final bool detectedFilled;
  BubbleReading(this.question, this.option, this.fillRatio, this.detectedFilled);
}

class OmrScanOutcome {
  final Map<int, List<int>> marked;
  final List<BubbleReading> readings;
  final String? rollNumber; // read from the bubbled roll grid, null if unreadable
  final double confidence;
  final List<int> ambiguousQuestions;
  final Uint8List debugPng;
  final String? failureReason; // set when registration failed outright

  OmrScanOutcome({
    required this.marked,
    required this.readings,
    required this.rollNumber,
    required this.confidence,
    required this.ambiguousQuestions,
    required this.debugPng,
    this.failureReason,
  });

  bool get registered => failureReason == null;
}

/// Maps the unit square onto an arbitrary quadrilateral (Heckbert's
/// projective mapping). This is what corrects for the photo being rotated,
/// tilted, or shot at an angle — the whole reason manual calibration is no
/// longer needed.
class _Homography {
  late final double a, b, c, d, e, f, g, h;

  _Homography(Point<double> p0, Point<double> p1, Point<double> p2, Point<double> p3) {
    final dx1 = p1.x - p2.x, dx2 = p3.x - p2.x, dx3 = p0.x - p1.x + p2.x - p3.x;
    final dy1 = p1.y - p2.y, dy2 = p3.y - p2.y, dy3 = p0.y - p1.y + p2.y - p3.y;

    if (dx3.abs() < 1e-9 && dy3.abs() < 1e-9) {
      a = p1.x - p0.x; b = p2.x - p1.x; c = p0.x;
      d = p1.y - p0.y; e = p2.y - p1.y; f = p0.y;
      g = 0; h = 0;
    } else {
      final den = dx1 * dy2 - dx2 * dy1;
      g = (dx3 * dy2 - dx2 * dy3) / den;
      h = (dx1 * dy3 - dx3 * dy1) / den;
      a = p1.x - p0.x + g * p1.x;
      b = p3.x - p0.x + h * p3.x;
      c = p0.x;
      d = p1.y - p0.y + g * p1.y;
      e = p3.y - p0.y + h * p3.y;
      f = p0.y;
    }
  }

  Point<double> map(double u, double v) {
    final w = g * u + h * v + 1;
    return Point<double>((a * u + b * v + c) / w, (d * u + e * v + f) / w);
  }
}

class _Blob {
  int minX, minY, maxX, maxY, area;
  _Blob(this.minX, this.minY, this.maxX, this.maxY, this.area);
  double get cx => (minX + maxX) / 2;
  double get cy => (minY + maxY) / 2;
  int get w => maxX - minX + 1;
  int get h => maxY - minY + 1;
}

/// Connected-component labelling over a binary mask (iterative, so no
/// stack overflow on large blobs).
List<_Blob> _findBlobs(Uint8List mask, int w, int h, int minArea, int maxArea) {
  final visited = Uint8List(w * h);
  final blobs = <_Blob>[];
  final queue = Int32List(w * h);

  for (int start = 0; start < w * h; start++) {
    if (mask[start] == 0 || visited[start] != 0) continue;
    int head = 0, tail = 0;
    queue[tail++] = start;
    visited[start] = 1;
    int minX = w, minY = h, maxX = 0, maxY = 0, area = 0;

    while (head < tail) {
      final idx = queue[head++];
      final x = idx % w, y = idx ~/ w;
      area++;
      if (x < minX) minX = x;
      if (x > maxX) maxX = x;
      if (y < minY) minY = y;
      if (y > maxY) maxY = y;

      if (x > 0) { final n = idx - 1; if (mask[n] != 0 && visited[n] == 0) { visited[n] = 1; queue[tail++] = n; } }
      if (x < w - 1) { final n = idx + 1; if (mask[n] != 0 && visited[n] == 0) { visited[n] = 1; queue[tail++] = n; } }
      if (y > 0) { final n = idx - w; if (mask[n] != 0 && visited[n] == 0) { visited[n] = 1; queue[tail++] = n; } }
      if (y < h - 1) { final n = idx + w; if (mask[n] != 0 && visited[n] == 0) { visited[n] = 1; queue[tail++] = n; } }
    }
    if (area >= minArea && area <= maxArea) {
      blobs.add(_Blob(minX, minY, maxX, maxY, area));
    }
  }
  return blobs;
}

Map<String, dynamic> _processIsolate(Map<String, dynamic> args) {
  final bytes = args['bytes'] as Uint8List;
  final totalQuestions = args['totalQuestions'] as int;
  final t = kDefaultSheetTemplate;

  final decoded = img.decodeImage(bytes);
  if (decoded == null) throw StateError('Could not decode the captured image.');
  var image = img.bakeOrientation(decoded);

  const targetWidth = 1500;
  if (image.width > targetWidth) {
    image = img.copyResize(image, width: targetWidth, interpolation: img.Interpolation.average);
  }
  final w = image.width, h = image.height;

  // Channel split. Black ink is dark in RED; the red printing is not.
  final red = Uint8List(w * h);
  final green = Uint8List(w * h);
  for (int y = 0; y < h; y++) {
    for (int x = 0; x < w; x++) {
      final p = image.getPixel(x, y);
      final i = y * w + x;
      red[i] = p.r.toInt().clamp(0, 255);
      green[i] = p.g.toInt().clamp(0, 255);
    }
  }

  final sortedRed = Uint8List.fromList(red)..sort();
  final paperWhite = sortedRed[(sortedRed.length * 0.85).floor()].toDouble();
  final blackCut = max(paperWhite * 0.45, 30.0);
  final inkCut = max(paperWhite * 0.62, 40.0);

  Uint8List debugFail() => Uint8List.fromList(img.encodePng(image));

  // ---- Find the printed timing marks (solid black rectangles) ----
  final blackMask = Uint8List(w * h);
  for (int i = 0; i < w * h; i++) {
    blackMask[i] = red[i] < blackCut ? 1 : 0;
  }
  final minMarkArea = (w * 0.004 * w * 0.008).round();
  final blobs = _findBlobs(blackMask, w, h, max(minMarkArea, 20), (w * w * 0.004).round());

  final marks = <_Blob>[];
  for (final blk in blobs) {
    final fill = blk.area / (blk.w * blk.h);
    final ar = blk.w / blk.h;
    final wn = blk.w / w, hn = blk.h / w;
    if (fill > 0.70 && ar > 0.18 && ar < 0.95 && wn > 0.0035 && wn < 0.040 && hn > 0.007 && hn < 0.050) {
      marks.add(blk);
    }
  }

  if (marks.length < 24) {
    return {
      'failure': 'Could not find the sheet\'s registration marks (found ${marks.length}). '
          'Make sure the whole sheet is inside the frame, lying flat and evenly lit.',
      'debugPng': debugFail(),
    };
  }

  // Split into the top and bottom timing bands at the largest vertical gap.
  marks.sort((p, q) => p.cy.compareTo(q.cy));
  int splitIdx = -1;
  double biggestGap = 0;
  for (int i = 1; i < marks.length; i++) {
    final gap = marks[i].cy - marks[i - 1].cy;
    if (gap > biggestGap) {
      biggestGap = gap;
      splitIdx = i;
    }
  }
  if (splitIdx < 10 || marks.length - splitIdx < 10 || biggestGap < h * 0.15) {
    return {
      'failure': 'Found marks but could not separate the top and bottom rows. '
          'Make sure both black mark strips (above and below the answer block) are visible.',
      'debugPng': debugFail(),
    };
  }
  final topBand = marks.sublist(0, splitIdx);
  final botBand = marks.sublist(splitIdx);

  _Blob leftMost(List<_Blob> l) => l.reduce((a, b) => a.cx <= b.cx ? a : b);
  _Blob rightMost(List<_Blob> l) => l.reduce((a, b) => a.cx >= b.cx ? a : b);

  final tl = leftMost(topBand), tr = rightMost(topBand);
  final bl = leftMost(botBand), br = rightMost(botBand);

  final H = _Homography(
    Point<double>(tl.cx, tl.cy),
    Point<double>(tr.cx, tr.cy),
    Point<double>(br.cx, br.cy),
    Point<double>(bl.cx, bl.cy),
  );

  final anchorSpan = sqrt(pow(tr.cx - tl.cx, 2) + pow(tr.cy - tl.cy, 2));
  final bubbleR = max(t.bubbleRadiusU * anchorSpan, 3.0);
  final rollR = max(t.rollBubbleRadiusU * anchorSpan, 3.0);

  double measureFill(Point<double> p, double radius) {
    final inner = radius * 0.68;
    final r0 = inner.ceil();
    int inked = 0, total = 0;
    for (int dy = -r0; dy <= r0; dy++) {
      for (int dx = -r0; dx <= r0; dx++) {
        if (dx * dx + dy * dy > inner * inner) continue;
        final px = (p.x + dx).round(), py = (p.y + dy).round();
        if (px < 0 || py < 0 || px >= w || py >= h) continue;
        total++;
        if (red[py * w + px] < inkCut) inked++;
      }
    }
    return total == 0 ? 0.0 : inked / total;
  }

  // ---- Sample the answer grid ----
  final readings = <Map<String, dynamic>>[];
  for (final col in t.columns) {
    for (int r = 0; r < col.questionCount; r++) {
      final qNo = col.startQuestion + r;
      if (qNo > totalQuestions) continue;
      for (int o = 0; o < col.optionU.length; o++) {
        final p = H.map(col.optionU[o], t.rowV[r]);
        readings.add({'q': qNo, 'o': o, 'f': measureFill(p, bubbleR), 'x': p.x, 'y': p.y, 'd': false});
      }
    }
  }

  // ---- Decide filled vs empty (Otsu over fill ratios) ----
  final ratios = readings.map((m) => m['f'] as double).toList();
  double cut = _otsu(ratios).clamp(0.28, 0.70);
  const hardEmpty = 0.16, hardFilled = 0.78;

  final ambiguous = <int>{};
  for (final m in readings) {
    final f = m['f'] as double;
    m['d'] = f >= hardFilled || (f > hardEmpty && f >= cut);
    if (f > hardEmpty && f < hardFilled && (f - cut).abs() < 0.12) ambiguous.add(m['q'] as int);
  }

  // ---- Read the bubbled roll number ----
  final rollDigits = <String>[];
  bool rollOk = true;
  for (int d = 0; d < t.rollColumnU.length; d++) {
    double best = -1;
    int bestDigit = -1;
    int hits = 0;
    for (int digit = 0; digit < t.rollRowV.length; digit++) {
      final p = H.map(t.rollColumnU[d], t.rollRowV[digit]);
      final f = measureFill(p, rollR);
      if (f > 0.45) hits++;
      if (f > best) {
        best = f;
        bestDigit = digit;
      }
    }
    if (best > 0.45 && hits == 1) {
      rollDigits.add(bestDigit.toString());
    } else if (best <= 0.45) {
      rollDigits.add(''); // that digit column left blank
    } else {
      rollOk = false; // more than one bubble in a digit column
      break;
    }
  }
  final rollJoined = rollDigits.join();
  final rollNumber = (rollOk && rollJoined.isNotEmpty) ? rollJoined : null;

  // ---- Confidence ----
  final filledVals = readings.where((m) => m['d'] as bool).map((m) => m['f'] as double).toList();
  final emptyVals = readings.where((m) => !(m['d'] as bool)).map((m) => m['f'] as double).toList();
  double confidence;
  if (filledVals.isEmpty || emptyVals.isEmpty) {
    confidence = emptyVals.isNotEmpty ? 0.85 : 0.2;
  } else {
    final mf = filledVals.reduce((a, b) => a + b) / filledVals.length;
    final me = emptyVals.reduce((a, b) => a + b) / emptyVals.length;
    confidence = ((mf - me) / 0.6).clamp(0.0, 1.0);
  }

  // ---- Annotated debug image ----
  final debug = image.clone();
  final cGreen = img.ColorRgb8(0, 220, 80);
  final cRed = img.ColorRgb8(255, 40, 40);
  final cYellow = img.ColorRgb8(255, 210, 0);
  final cBlue = img.ColorRgb8(40, 120, 255);
  for (final m in marks) {
    img.drawRect(debug, x1: m.minX, y1: m.minY, x2: m.maxX, y2: m.maxY, color: cBlue);
  }
  for (final m in readings) {
    final f = m['d'] as bool;
    final fv = m['f'] as double;
    final borderline = fv > hardEmpty && fv < hardFilled && (fv - cut).abs() < 0.12;
    final color = f ? cGreen : (borderline ? cYellow : cRed);
    final x = (m['x'] as double).round(), y = (m['y'] as double).round();
    img.drawCircle(debug, x: x, y: y, radius: bubbleR.round(), color: color);
    if (f) img.drawCircle(debug, x: x, y: y, radius: max(bubbleR.round() - 2, 2), color: color);
  }
  for (int d = 0; d < t.rollColumnU.length; d++) {
    for (int digit = 0; digit < t.rollRowV.length; digit++) {
      final p = H.map(t.rollColumnU[d], t.rollRowV[digit]);
      final filled = measureFill(p, rollR) > 0.45;
      img.drawCircle(debug, x: p.x.round(), y: p.y.round(), radius: rollR.round(),
          color: filled ? cGreen : cRed);
    }
  }

  final marked = <String, List<int>>{};
  for (final m in readings) {
    final q = (m['q'] as int).toString();
    marked.putIfAbsent(q, () => <int>[]);
    if (m['d'] as bool) marked[q]!.add(m['o'] as int);
  }

  return {
    'marked': marked,
    'readings': readings,
    'rollNumber': rollNumber,
    'confidence': confidence,
    'ambiguous': ambiguous.toList()..sort(),
    'debugPng': Uint8List.fromList(img.encodePng(debug)),
  };
}

double _otsu(List<double> vals) {
  if (vals.isEmpty) return 0.45;
  const bins = 100;
  final hist = List<int>.filled(bins, 0);
  for (final v in vals) {
    hist[(v * (bins - 1)).round().clamp(0, bins - 1)]++;
  }
  final total = vals.length;
  double sumAll = 0;
  for (int i = 0; i < bins; i++) sumAll += i * hist[i];
  double sumB = 0;
  int wB = 0;
  double maxVar = -1;
  int th = 45;
  for (int i = 0; i < bins; i++) {
    wB += hist[i];
    if (wB == 0) continue;
    final wF = total - wB;
    if (wF == 0) break;
    sumB += i * hist[i];
    final mB = sumB / wB, mF = (sumAll - sumB) / wF;
    final between = wB * wF * (mB - mF) * (mB - mF);
    if (between > maxVar) {
      maxVar = between;
      th = i;
    }
  }
  return th / (bins - 1);
}

class OmrProcessor {
  /// Scans a photo with NO calibration — the sheet's own printed timing
  /// marks are located automatically and the built-in template is projected
  /// onto them, correcting for rotation, tilt and perspective.
  static Future<OmrScanOutcome> scan(File imageFile, Exam exam) async {
    final bytes = await imageFile.readAsBytes();
    final res = await compute(_processIsolate, {
      'bytes': bytes,
      'totalQuestions': exam.totalQuestions,
    });

    if (res.containsKey('failure')) {
      return OmrScanOutcome(
        marked: const {},
        readings: const [],
        rollNumber: null,
        confidence: 0,
        ambiguousQuestions: const [],
        debugPng: res['debugPng'] as Uint8List,
        failureReason: res['failure'] as String,
      );
    }

    final rawMarked = (res['marked'] as Map).cast<String, dynamic>();
    final marked = <int, List<int>>{};
    rawMarked.forEach((k, v) => marked[int.parse(k)] = List<int>.from(v));

    final readings = (res['readings'] as List)
        .cast<Map<String, dynamic>>()
        .map((m) => BubbleReading(m['q'], m['o'], (m['f'] as num).toDouble(), m['d']))
        .toList();

    return OmrScanOutcome(
      marked: marked,
      readings: readings,
      rollNumber: res['rollNumber'] as String?,
      confidence: (res['confidence'] as num).toDouble(),
      ambiguousQuestions: List<int>.from(res['ambiguous']),
      debugPng: res['debugPng'] as Uint8List,
    );
  }

  static (int, int, int, double) grade(Exam exam, Map<int, List<int>> marked) {
    int correct = 0, wrong = 0, unattempted = 0;
    for (int q = 1; q <= exam.totalQuestions; q++) {
      final key = List<int>.from(exam.answerKey[q] ?? const <int>[])..sort();
      final given = List<int>.from(marked[q] ?? const <int>[])..sort();
      if (given.isEmpty) {
        unattempted++;
      } else if (_eq(given, key)) {
        correct++;
      } else {
        wrong++;
      }
    }
    return (correct, wrong, unattempted, correct.toDouble());
  }

  static bool _eq(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
