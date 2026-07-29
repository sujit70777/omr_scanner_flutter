import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../db/db_helper.dart';
import '../models/exam.dart';

class AddExamScreen extends StatefulWidget {
  const AddExamScreen({super.key});

  @override
  State<AddExamScreen> createState() => _AddExamScreenState();
}

class _AddExamScreenState extends State<AddExamScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _countCtrl = TextEditingController();
  int _optionsCount = 4;
  bool _saving = false;

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final exam = Exam(
      name: _nameCtrl.text.trim(),
      totalQuestions: int.parse(_countCtrl.text.trim()),
      optionsCount: _optionsCount,
      createdAt: DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now()),
    );
    await DBHelper.instance.insertExam(exam);
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Exam')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'Exam name', border: OutlineInputBorder()),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter exam name' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _countCtrl,
                decoration: const InputDecoration(labelText: 'Total number of questions', border: OutlineInputBorder()),
                keyboardType: TextInputType.number,
                validator: (v) {
                  final n = int.tryParse(v ?? '');
                  if (n == null || n <= 0) return 'Enter a valid question count';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                value: _optionsCount,
                decoration: const InputDecoration(labelText: 'Options per question', border: OutlineInputBorder()),
                items: const [2, 3, 4, 5]
                    .map((n) => DropdownMenuItem(value: n, child: Text('$n options')))
                    .toList(),
                onChanged: (v) => setState(() => _optionsCount = v ?? 4),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Add exam'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
