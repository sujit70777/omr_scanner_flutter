import 'package:flutter/material.dart';
import '../db/db_helper.dart';
import '../models/exam.dart';
import 'add_exam_screen.dart';
import 'exam_detail_screen.dart';

class ExamListScreen extends StatefulWidget {
  const ExamListScreen({super.key});

  @override
  State<ExamListScreen> createState() => _ExamListScreenState();
}

class _ExamListScreenState extends State<ExamListScreen> {
  List<Exam> _exams = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final exams = await DBHelper.instance.getExams();
    setState(() {
      _exams = exams;
      _loading = false;
    });
  }

  Future<void> _addExam() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const AddExamScreen()),
    );
    if (created == true) _load();
  }

  Future<void> _openExam(Exam exam) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ExamDetailScreen(examId: exam.id!)),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Exams')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _exams.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'No exams yet.\nTap the + button to add your first exam.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  ),
                )
              : ListView.separated(
                  itemCount: _exams.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final e = _exams[i];
                    return ListTile(
                      leading: CircleAvatar(child: Text('${e.totalQuestions}')),
                      title: Text(e.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Builder(builder: (_) {
                        final issues = [
                          if (!e.hasAnswerKey) 'Answer key not set',
                        ];
                        return Text(
                          issues.isEmpty ? 'Ready to scan' : issues.join(' · '),
                          style: TextStyle(color: issues.isEmpty ? Colors.green[700] : Colors.orange[800]),
                        );
                      }),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _openExam(e),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addExam,
        child: const Icon(Icons.add),
      ),
    );
  }
}
