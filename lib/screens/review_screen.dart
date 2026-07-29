import 'package:flutter/material.dart';
import '../models/exam.dart';
import '../services/omr_processor.dart';

/// What the user confirmed: the corrected marks plus the roll number.
class ReviewResult {
  final String rollNumber;
  final Map<int, List<int>> marked;
  ReviewResult({required this.rollNumber, required this.marked});
}

/// Shown after every scan. No automatic OMR is 100% on every sheet, so
/// instead of pretending otherwise this screen makes the detection fully
/// visible and correctable:
///   - the annotated photo shows exactly where each bubble was sampled
///     (green = read as filled, red = read as empty, yellow = borderline)
///   - every question is listed with tappable option chips, so a wrong
///     read is one tap to fix
///   - borderline questions are pulled to your attention automatically
/// Whatever you confirm here is what gets saved — so the stored result is
/// exact by construction.
class ReviewScreen extends StatefulWidget {
  final Exam exam;
  final OmrScanOutcome outcome;

  const ReviewScreen({super.key, required this.exam, required this.outcome});

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  late Map<int, Set<int>> _marked;
  late TextEditingController _rollCtrl;
  bool _showOnlyIssues = false;
  bool _imageExpanded = false;

  @override
  void initState() {
    super.initState();
    _rollCtrl = TextEditingController(text: widget.outcome.rollNumber ?? '');
    _marked = {
      for (int q = 1; q <= widget.exam.totalQuestions; q++)
        q: Set<int>.from(widget.outcome.marked[q] ?? const <int>[])
    };
    // If anything looked borderline, open filtered to those by default.
    _showOnlyIssues = widget.outcome.ambiguousQuestions.isNotEmpty;
  }

  /// Questions worth a human look: borderline fill readings, multi-marks
  /// where the key expects a single answer, and blanks.
  Set<int> get _issueQuestions {
    final issues = <int>{...widget.outcome.ambiguousQuestions};
    for (int q = 1; q <= widget.exam.totalQuestions; q++) {
      final given = _marked[q]!;
      final key = widget.exam.answerKey[q] ?? const <int>[];
      if (given.isEmpty) issues.add(q);
      if (given.length > 1 && key.length <= 1) issues.add(q);
    }
    return issues;
  }

  double _fillFor(int q, int o) {
    for (final r in widget.outcome.readings) {
      if (r.question == q && r.option == o) return r.fillRatio;
    }
    return 0;
  }

  void _confirm() {
    if (_rollCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter the roll number before confirming')),
      );
      return;
    }
    Navigator.pop(context, ReviewResult(
      rollNumber: _rollCtrl.text.trim(),
      marked: {for (final e in _marked.entries) e.key: (e.value.toList()..sort())},
    ));
  }

  @override
  void dispose() {
    _rollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final exam = widget.exam;
    final issues = _issueQuestions;
    final questions = List.generate(exam.totalQuestions, (i) => i + 1)
        .where((q) => !_showOnlyIssues || issues.contains(q))
        .toList();

    final conf = widget.outcome.confidence;
    final confColor = conf > 0.6 ? Colors.green : (conf > 0.35 ? Colors.orange : Colors.red);

    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Review Scan'),
          actions: [
            IconButton(
              tooltip: _imageExpanded ? 'Hide image' : 'Show scan image',
              icon: Icon(_imageExpanded ? Icons.image_not_supported_outlined : Icons.image_outlined),
              onPressed: () => setState(() => _imageExpanded = !_imageExpanded),
            ),
          ],
        ),
        body: Column(
          children: [
            // ---- confidence banner ----
            Container(
              width: double.infinity,
              color: confColor.withOpacity(0.12),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  Icon(conf > 0.6 ? Icons.verified : Icons.warning_amber_rounded, color: confColor, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      conf > 0.6
                          ? 'Clean read — ${issues.length} question(s) still worth a glance'
                          : 'Weak read (${(conf * 100).round()}%) — check the image and fix anything wrong below',
                      style: TextStyle(color: confColor, fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),

            // ---- annotated scan image ----
            if (_imageExpanded)
              SizedBox(
                height: 280,
                child: Container(
                  color: Colors.black12,
                  child: InteractiveViewer(
                    maxScale: 8,
                    child: Center(child: Image.memory(widget.outcome.debugPng)),
                  ),
                ),
              ),
            if (_imageExpanded)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Text(
                  'Pinch to zoom. Green = read as filled · Red = read as empty · Yellow = borderline.',
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ),

            // ---- roll number (typed manually — answers only are auto-read) ----
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
              child: TextField(
                controller: _rollCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Roll number',
                  border: OutlineInputBorder(),
                  isDense: true,
                  prefixIcon: Icon(Icons.badge_outlined),
                  helperText: 'Type the roll number from the sheet',
                  helperStyle: TextStyle(fontSize: 11),
                ),
              ),
            ),

            // ---- filter toggle ----
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Text('${issues.length} to check', style: const TextStyle(fontWeight: FontWeight.w600)),
                  const Spacer(),
                  const Text('Only show these', style: TextStyle(fontSize: 13)),
                  Switch(
                    value: _showOnlyIssues,
                    onChanged: (v) => setState(() => _showOnlyIssues = v),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // ---- question list ----
            Expanded(
              child: questions.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text('Nothing flagged — everything read cleanly.',
                            textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                      ),
                    )
                  : ListView.builder(
                      itemCount: questions.length,
                      itemBuilder: (context, i) {
                        final q = questions[i];
                        final isIssue = issues.contains(q);
                        return Container(
                          color: isIssue ? Colors.amber.withOpacity(0.07) : null,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 44,
                                child: Text('Q$q',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: isIssue ? Colors.orange[900] : null,
                                    )),
                              ),
                              Expanded(
                                child: Wrap(
                                  spacing: 6,
                                  children: List.generate(exam.optionsCount, (o) {
                                    final sel = _marked[q]!.contains(o);
                                    final label = o < optionLabelsBn.length ? optionLabelsBn[o] : '${o + 1}';
                                    final fill = _fillFor(q, o);
                                    return GestureDetector(
                                      onLongPress: () {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            duration: const Duration(seconds: 2),
                                            content: Text('Q$q · $label — ${(fill * 100).round()}% of the bubble was inked'),
                                          ),
                                        );
                                      },
                                      child: FilterChip(
                                        label: Text(label),
                                        selected: sel,
                                        showCheckmark: false,
                                        onSelected: (v) {
                                          setState(() {
                                            if (v) {
                                              _marked[q]!.add(o);
                                            } else {
                                              _marked[q]!.remove(o);
                                            }
                                          });
                                        },
                                      ),
                                    );
                                  }),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, null),
                    child: const Text('Rescan'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    onPressed: _confirm,
                    child: const Text('Confirm & continue'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
