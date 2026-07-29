import 'dart:io';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import '../models/exam.dart';
import '../models/student_result.dart';

enum ExportFormat { csv, excel, pdf }

/// Builds a summary results file (roll, counts, score, time) and opens the
/// system share sheet so the user can save or send it.
class ResultsExporter {
  static Future<void> export({
    required Exam exam,
    required List<StudentResult> results,
    required ExportFormat format,
  }) async {
    final sorted = [...results]
      ..sort((a, b) {
        final byScore = b.score.compareTo(a.score);
        if (byScore != 0) return byScore;
        return a.rollNumber.compareTo(b.rollNumber);
      });

    final stamp = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
    final safeName = exam.name
        .replaceAll(RegExp(r'[^\w\s-]'), '')
        .trim()
        .replaceAll(RegExp(r'\s+'), '_');
    final base = '${safeName.isEmpty ? 'exam' : safeName}_results_$stamp';

    late final String path;
    late final String mime;
    switch (format) {
      case ExportFormat.csv:
        path = await _writeCsv(base, exam, sorted);
        mime = 'text/csv';
      case ExportFormat.excel:
        path = await _writeExcel(base, exam, sorted);
        mime = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case ExportFormat.pdf:
        path = await _writePdf(base, exam, sorted);
        mime = 'application/pdf';
    }

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(path, mimeType: mime)],
        subject: '${exam.name} — results',
        text: 'OMR results for ${exam.name}',
      ),
    );
  }

  static List<String> _headers() => const [
        'Rank',
        'Roll Number',
        'Correct',
        'Wrong',
        'Blank',
        'Score',
        'Scanned At',
      ];

  static List<String> _row(int rank, StudentResult r) => [
        '$rank',
        r.rollNumber,
        '${r.correctCount}',
        '${r.wrongCount}',
        '${r.unattemptedCount}',
        _scoreText(r.score),
        r.scannedAt,
      ];

  static String _scoreText(double s) =>
      s == s.roundToDouble() ? s.toStringAsFixed(0) : s.toStringAsFixed(1);

  static Future<String> _writeCsv(
    String base,
    Exam exam,
    List<StudentResult> results,
  ) async {
    final buf = StringBuffer();
    buf.writeln(_csvEscape(exam.name));
    buf.writeln(
        'Questions,${exam.totalQuestions},Students,${results.length},Exported,${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}');
    buf.writeln();
    buf.writeln(_headers().map(_csvEscape).join(','));
    for (int i = 0; i < results.length; i++) {
      buf.writeln(_row(i + 1, results[i]).map(_csvEscape).join(','));
    }
    final dir = await getTemporaryDirectory();
    final file = File(p.join(dir.path, '$base.csv'));
    await file.writeAsString(buf.toString(), flush: true);
    return file.path;
  }

  static String _csvEscape(String v) {
    if (v.contains(',') || v.contains('"') || v.contains('\n')) {
      return '"${v.replaceAll('"', '""')}"';
    }
    return v;
  }

  static Future<String> _writeExcel(
    String base,
    Exam exam,
    List<StudentResult> results,
  ) async {
    final book = Excel.createExcel();
    final defaultName = book.getDefaultSheet() ?? 'Sheet1';
    book.rename(defaultName, 'Results');
    final sheet = book['Results'];

    sheet.appendRow([TextCellValue(exam.name)]);
    sheet.appendRow([
      TextCellValue('Questions'),
      IntCellValue(exam.totalQuestions),
      TextCellValue('Students'),
      IntCellValue(results.length),
      TextCellValue('Exported'),
      TextCellValue(DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())),
    ]);
    sheet.appendRow([]);
    sheet.appendRow(_headers().map((h) => TextCellValue(h)).toList());

    for (int i = 0; i < results.length; i++) {
      final r = results[i];
      sheet.appendRow([
        IntCellValue(i + 1),
        TextCellValue(r.rollNumber),
        IntCellValue(r.correctCount),
        IntCellValue(r.wrongCount),
        IntCellValue(r.unattemptedCount),
        DoubleCellValue(r.score),
        TextCellValue(r.scannedAt),
      ]);
    }

    final bytes = book.encode();
    if (bytes == null) throw StateError('Could not build Excel file');
    final dir = await getTemporaryDirectory();
    final file = File(p.join(dir.path, '$base.xlsx'));
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  static Future<String> _writePdf(
    String base,
    Exam exam,
    List<StudentResult> results,
  ) async {
    final doc = pw.Document();
    final exported = DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now());
    final headers = _headers();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(exam.name,
                style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 4),
            pw.Text(
              '${exam.totalQuestions} questions · ${results.length} students · Exported $exported',
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
            ),
            pw.SizedBox(height: 12),
            pw.Divider(thickness: 1),
            pw.SizedBox(height: 8),
          ],
        ),
        build: (ctx) => [
          pw.TableHelper.fromTextArray(
            headers: headers,
            data: [
              for (int i = 0; i < results.length; i++) _row(i + 1, results[i]),
            ],
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
            cellStyle: const pw.TextStyle(fontSize: 9),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
            cellAlignments: {
              0: pw.Alignment.center,
              2: pw.Alignment.center,
              3: pw.Alignment.center,
              4: pw.Alignment.center,
              5: pw.Alignment.centerRight,
            },
            columnWidths: {
              0: const pw.FixedColumnWidth(36),
              1: const pw.FlexColumnWidth(2),
              2: const pw.FixedColumnWidth(48),
              3: const pw.FixedColumnWidth(48),
              4: const pw.FixedColumnWidth(48),
              5: const pw.FixedColumnWidth(48),
              6: const pw.FlexColumnWidth(2.2),
            },
          ),
        ],
        footer: (ctx) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Page ${ctx.pageNumber} of ${ctx.pagesCount}',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
          ),
        ),
      ),
    );

    final dir = await getTemporaryDirectory();
    final file = File(p.join(dir.path, '$base.pdf'));
    await file.writeAsBytes(await doc.save(), flush: true);
    return file.path;
  }
}
