import 'package:flutter/material.dart';
import '../db/db_helper.dart';
import '../models/exam.dart';
import '../models/exam_settings.dart';

class ExamSettingsScreen extends StatefulWidget {
  final int examId;
  const ExamSettingsScreen({super.key, required this.examId});

  @override
  State<ExamSettingsScreen> createState() => _ExamSettingsScreenState();
}

class _ExamSettingsScreenState extends State<ExamSettingsScreen> {
  Exam? _exam;
  late ExamSettings _settings;
  bool _loading = true;
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
      _settings = e?.settings ?? const ExamSettings();
      _loading = false;
    });
  }

  Future<void> _save() async {
    if (_exam == null) return;
    setState(() => _saving = true);
    await DBHelper.instance.updateExam(_exam!.copyWith(settings: _settings));
    if (mounted) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Exam settings saved')),
      );
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _exam == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Exam settings'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Save'),
          ),
        ],
      ),
      body: ListView(
        children: [
          const _SectionHeader('Multiple marks'),
          SwitchListTile(
            title: const Text('Count multi-mark if answer is filled'),
            subtitle: const Text(
              'Student filled more than one bubble, but the correct answer is among them. '
              'ON = count as correct. OFF = count as wrong.',
            ),
            value: _settings.multiMarkCountsIfIncludesAnswer,
            onChanged: (v) => setState(
              () => _settings = _settings.copyWith(multiMarkCountsIfIncludesAnswer: v),
            ),
          ),
          const Divider(height: 1),
          SwitchListTile(
            title: const Text('Count partial multi-answer'),
            subtitle: const Text(
              'Question has several correct options and the student did not fill all of them. '
              'ON = count as correct if at least one correct option is filled. '
              'OFF = require every correct option.',
            ),
            value: _settings.partialMultiAnswerCounts,
            onChanged: (v) => setState(
              () => _settings = _settings.copyWith(partialMultiAnswerCounts: v),
            ),
          ),
          const _SectionHeader('Scoring'),
          ListTile(
            title: const Text('Marks per correct'),
            subtitle: Text(_settings.marksPerCorrect.toStringAsFixed(
                _settings.marksPerCorrect == _settings.marksPerCorrect.roundToDouble() ? 0 : 1)),
            trailing: SizedBox(
              width: 120,
              child: Slider(
                min: 0.5,
                max: 5,
                divisions: 9,
                label: _settings.marksPerCorrect.toString(),
                value: _settings.marksPerCorrect.clamp(0.5, 5),
                onChanged: (v) => setState(
                  () => _settings = _settings.copyWith(marksPerCorrect: v),
                ),
              ),
            ),
          ),
          ListTile(
            title: const Text('Negative mark per wrong'),
            subtitle: Text(
              _settings.negativeMarkPerWrong <= 0
                  ? 'Off'
                  : '−${_settings.negativeMarkPerWrong.toStringAsFixed(2)}',
            ),
            trailing: SizedBox(
              width: 120,
              child: Slider(
                min: 0,
                max: 2,
                divisions: 8,
                label: _settings.negativeMarkPerWrong.toStringAsFixed(2),
                value: _settings.negativeMarkPerWrong.clamp(0, 2),
                onChanged: (v) => setState(
                  () => _settings = _settings.copyWith(negativeMarkPerWrong: v),
                ),
              ),
            ),
          ),
          SwitchListTile(
            title: const Text('Count blank as wrong'),
            subtitle: const Text(
              'Unanswered questions count as wrong (and take negative marks if set). '
              'OFF = leave them as blank / unattempted.',
            ),
            value: _settings.countBlankAsWrong,
            onChanged: (v) => setState(
              () => _settings = _settings.copyWith(countBlankAsWrong: v),
            ),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Defaults are strict: exact match only, 1 mark each, no negative marking. '
              'Already-saved results keep their old scores — new scans use these rules.',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
      child: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}
