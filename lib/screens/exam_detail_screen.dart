import 'package:flutter/material.dart';
import '../db/db_helper.dart';
import '../models/exam.dart';
import 'answer_key_screen.dart';
import 'detection_test_screen.dart';
import 'history_screen.dart';
import 'scan_screen.dart';

class ExamDetailScreen extends StatefulWidget {
  final int examId;
  const ExamDetailScreen({super.key, required this.examId});

  @override
  State<ExamDetailScreen> createState() => _ExamDetailScreenState();
}

class _ExamDetailScreenState extends State<ExamDetailScreen> {
  Exam? _exam;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final e = await DBHelper.instance.getExam(widget.examId);
    setState(() => _exam = e);
  }

  Future<void> _deleteExam() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete exam?'),
        content: Text('This will remove "${_exam!.name}" and all its scanned results.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirm == true) {
      await DBHelper.instance.deleteExam(widget.examId);
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final exam = _exam;
    return Scaffold(
      appBar: AppBar(
        title: Text(exam?.name ?? 'Exam'),
        actions: [
          IconButton(onPressed: _deleteExam, icon: const Icon(Icons.delete_outline)),
        ],
      ),
      body: exam == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${exam.totalQuestions} questions · ${exam.optionsCount} options each',
                            style: const TextStyle(fontSize: 15)),
                        const SizedBox(height: 4),
                        Text('Created: ${exam.createdAt}', style: const TextStyle(color: Colors.grey)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _ActionTile(
                  icon: Icons.checklist_rtl,
                  title: 'Answer Key',
                  subtitle: exam.hasAnswerKey ? 'Set for all ${exam.totalQuestions} questions' : 'Not set yet',
                  done: exam.hasAnswerKey,
                  onTap: () async {
                    await Navigator.push(context, MaterialPageRoute(builder: (_) => AnswerKeyScreen(examId: exam.id!)));
                    _load();
                  },
                ),
                _ActionTile(
                  icon: Icons.bug_report_outlined,
                  title: 'Test Detection',
                  subtitle: 'Check a sheet and see exactly what was read — use this if results look wrong',
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => DetectionTestScreen(examId: exam.id!))),
                ),
                _ActionTile(
                  icon: Icons.document_scanner,
                  title: 'Scan Sheets',
                  subtitle: 'Take or pick a photo — same capture as Test Detection',
                  enabled: exam.hasAnswerKey,
                  onTap: exam.hasAnswerKey
                      ? () async {
                          await Navigator.push(context,
                              MaterialPageRoute(builder: (_) => ScanScreen(examId: exam.id!)));
                          _load();
                        }
                      : null,
                ),
                _ActionTile(
                  icon: Icons.history,
                  title: 'History / Results',
                  subtitle: 'View all scanned students and their marks',
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => HistoryScreen(examId: exam.id!, examName: exam.name))),
                ),
              ],
            ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool done;
  final bool enabled;
  final VoidCallback? onTap;

  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.done = false,
    this.enabled = true,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        enabled: enabled,
        leading: Icon(icon, color: done ? Colors.green : null),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
        trailing: done ? const Icon(Icons.check_circle, color: Colors.green) : const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
