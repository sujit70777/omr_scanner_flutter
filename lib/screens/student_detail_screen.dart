import 'package:flutter/material.dart';
import '../db/db_helper.dart';
import '../models/exam.dart';
import '../models/student_result.dart';

class StudentDetailScreen extends StatefulWidget {
  final int resultId;
  final int examId;
  const StudentDetailScreen({super.key, required this.resultId, required this.examId});

  @override
  State<StudentDetailScreen> createState() => _StudentDetailScreenState();
}

class _StudentDetailScreenState extends State<StudentDetailScreen> {
  Exam? _exam;
  StudentResult? _result;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final exam = await DBHelper.instance.getExam(widget.examId);
    final result = await DBHelper.instance.getResult(widget.resultId);
    setState(() {
      _exam = exam;
      _result = result;
    });
  }

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete this result?'),
        content: Text('Remove roll number ${_result!.rollNumber} from history.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirm == true) {
      await DBHelper.instance.deleteResult(widget.resultId);
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final exam = _exam;
    final result = _result;
    if (exam == null || result == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(
        title: Text('Roll: ${result.rollNumber}'),
        actions: [IconButton(onPressed: _delete, icon: const Icon(Icons.delete_outline))],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _StatCol('Correct', '${result.correctCount}', Colors.green),
                _StatCol('Wrong', '${result.wrongCount}', Colors.red),
                _StatCol('Blank', '${result.unattemptedCount}', Colors.grey),
                _StatCol('Score', result.score.toStringAsFixed(0), Colors.indigo),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              itemCount: exam.totalQuestions,
              itemBuilder: (context, i) {
                final qNo = i + 1;
                final key = List<int>.from(exam.answerKey[qNo] ?? const [])..sort();
                final given = List<int>.from(result.marked[qNo] ?? const [])..sort();
                final isBlank = given.isEmpty;
                final isCorrect = !isBlank && _listEq(given, key);
                final color = isBlank ? Colors.grey : (isCorrect ? Colors.green : Colors.red);
                final icon = isBlank ? Icons.remove_circle_outline : (isCorrect ? Icons.check_circle : Icons.cancel);

                String labelsFor(List<int> idxs) =>
                    idxs.isEmpty ? '-' : idxs.map((i) => i < optionLabelsBn.length ? optionLabelsBn[i] : '${i + 1}').join(', ');

                return ListTile(
                  leading: Icon(icon, color: color),
                  title: Text('Question $qNo'),
                  subtitle: Text('Marked: ${labelsFor(given)}   ·   Correct: ${labelsFor(key)}'),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  bool _listEq(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

class _StatCol extends StatelessWidget {
  final String label, value;
  final Color color;
  const _StatCol(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: const TextStyle(color: Colors.grey)),
      ],
    );
  }
}
