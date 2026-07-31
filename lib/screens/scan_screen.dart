import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../db/db_helper.dart';
import '../models/exam.dart';
import '../models/student_result.dart';
import '../services/app_settings.dart';
import '../services/entitlement_service.dart';
import '../services/omr_processor.dart';
import '../services/premium_config.dart';
import 'paywall_screen.dart';
import 'review_screen.dart';

/// Capture-or-pick a sheet photo (same path as Test Detection), run OMR,
/// then open Review to confirm marks + type the roll number and save.
class ScanScreen extends StatefulWidget {
  final int examId;
  const ScanScreen({super.key, required this.examId});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  Exam? _exam;
  OmrScanOutcome? _outcome;
  bool _busy = false;
  String? _error;
  int _scannedCount = 0;

  @override
  void initState() {
    super.initState();
    DBHelper.instance.getExam(widget.examId).then((e) => setState(() => _exam = e));
  }

  Future<void> _run(ImageSource source) async {
    final ent = EntitlementService.instance;
    if (!await ent.canScanSheet()) {
      if (!mounted) return;
      await PaywallScreen.open(
        context,
        reason:
            'Free plan allows ${PremiumConfig.freeScansPerMonth} scans per month '
            '(${ent.scansUsedThisMonth} used). Unlock Premium for unlimited scans.',
      );
      if (!await ent.canScanSheet()) return;
    }

    setState(() {
      _busy = true;
      _error = null;
      _outcome = null;
    });
    try {
      final picked = await ImagePicker().pickImage(
        source: source,
        imageQuality: AppSettings.instance.imageQuality,
      );
      if (picked == null) {
        setState(() => _busy = false);
        return;
      }
      final outcome = await OmrProcessor.scan(File(picked.path), _exam!);
      if (!mounted) return;

      if (!outcome.registered) {
        setState(() {
          _outcome = outcome;
          _error = outcome.failureReason;
          _busy = false;
        });
        return;
      }

      setState(() {
        _outcome = outcome;
        _busy = false;
      });

      final confirmed = await Navigator.push<ReviewResult>(
        context,
        MaterialPageRoute(
          builder: (_) => ReviewScreen(exam: _exam!, outcome: outcome),
        ),
      );
      if (!mounted) return;
      if (confirmed == null) return;

      final (correct, wrong, unattempted, score) =
          OmrProcessor.grade(_exam!, confirmed.marked);
      await DBHelper.instance.insertResult(StudentResult(
        examId: widget.examId,
        rollNumber: confirmed.rollNumber,
        marked: confirmed.marked,
        correctCount: correct,
        wrongCount: wrong,
        unattemptedCount: unattempted,
        score: score,
        scannedAt: DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now()),
      ));
      await EntitlementService.instance.recordSuccessfulScan();
      if (!mounted) return;
      setState(() => _scannedCount++);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 2),
          backgroundColor: Colors.green[700],
          content: Text(
            'Roll ${confirmed.rollNumber} saved · $correct correct — scan the next sheet',
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final outcome = _outcome;
    return Scaffold(
      appBar: AppBar(
        title: Text(_exam?.name ?? 'Scan'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                'Saved: $_scannedCount',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
      body: _busy
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (_error != null)
                  Container(
                    width: double.infinity,
                    color: Colors.red.withOpacity(0.1),
                    padding: const EdgeInsets.all(12),
                    child: Text(_error!, style: const TextStyle(color: Colors.red)),
                  ),
                if (outcome != null && outcome.registered) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    color: Colors.indigo.withOpacity(0.06),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Confidence: ${(outcome.confidence * 100).round()}%',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Detected marks on ${outcome.marked.values.where((v) => v.isNotEmpty).length} question(s)',
                        ),
                        if (outcome.ambiguousQuestions.isNotEmpty)
                          Text(
                            'Borderline: Q${outcome.ambiguousQuestions.join(", Q")}',
                            style: const TextStyle(color: Colors.orange, fontSize: 12),
                          ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Container(
                      color: Colors.black12,
                      child: InteractiveViewer(
                        maxScale: 12,
                        child: Center(child: Image.memory(outcome.debugPng)),
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.all(10),
                    child: Text(
                      'Review opened after a successful read. Capture again for the next sheet.',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ] else if (outcome != null && !outcome.registered) ...[
                  Expanded(
                    child: Container(
                      color: Colors.black12,
                      child: InteractiveViewer(
                        maxScale: 12,
                        child: Center(child: Image.memory(outcome.debugPng)),
                      ),
                    ),
                  ),
                ] else
                  const Expanded(
                    child: Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'Take or pick a photo of a filled answer sheet.\n\n'
                          'Same capture path as Test Detection — then confirm marks and enter the roll number to save.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
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
                child: OutlinedButton.icon(
                  onPressed: _exam == null || _busy ? null : () => _run(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library),
                  label: const Text('From gallery'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _exam == null || _busy ? null : () => _run(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Take photo'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
