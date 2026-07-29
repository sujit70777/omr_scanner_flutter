import 'package:flutter/material.dart';
import '../db/db_helper.dart';
import '../models/exam.dart';
import '../services/app_settings.dart';

class AnswerKeyScreen extends StatefulWidget {
  final int examId;
  const AnswerKeyScreen({super.key, required this.examId});

  @override
  State<AnswerKeyScreen> createState() => _AnswerKeyScreenState();
}

class _AnswerKeyScreenState extends State<AnswerKeyScreen> {
  Exam? _exam;
  late Map<int, Set<int>> _selected; // questionNo -> selected option indices
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final e = await DBHelper.instance.getExam(widget.examId);
    setState(() {
      _exam = e;
      _selected = {
        for (int q = 1; q <= e!.totalQuestions; q++) q: Set<int>.from(e.answerKey[q] ?? const <int>[])
      };
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final answerKey = <int, List<int>>{
      for (final entry in _selected.entries) entry.key: entry.value.toList()..sort()
    };
    final updated = _exam!.copyWith(answerKey: answerKey);
    await DBHelper.instance.updateExam(updated);
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final exam = _exam;
    if (exam == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final unset = _selected.entries.where((e) => e.value.isEmpty).length;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Answer Key'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(child: Text(unset == 0 ? 'All set' : '$unset left', style: const TextStyle(fontSize: 14))),
          ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: exam.totalQuestions,
        itemBuilder: (context, i) {
          final qNo = i + 1;
          return Card(
            margin: const EdgeInsets.symmetric(vertical: 4),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  SizedBox(width: 40, child: Text('Q$qNo', style: const TextStyle(fontWeight: FontWeight.bold))),
                  Expanded(
                    child: Wrap(
                      spacing: 6,
                      children: List.generate(exam.optionsCount, (optIdx) {
                        final labels = AppSettings.instance.optionLabels;
                        final label = optIdx < labels.length ? labels[optIdx] : '${optIdx + 1}';
                        final isSel = _selected[qNo]!.contains(optIdx);
                        return FilterChip(
                          label: Text(label),
                          selected: isSel,
                          onSelected: (v) {
                            setState(() {
                              if (v) {
                                _selected[qNo]!.add(optIdx);
                              } else {
                                _selected[qNo]!.remove(optIdx);
                              }
                            });
                          },
                        );
                      }),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Save answer key'),
          ),
        ),
      ),
    );
  }
}
