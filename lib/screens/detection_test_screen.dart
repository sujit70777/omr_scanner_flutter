import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../db/db_helper.dart';
import '../models/exam.dart';
import '../services/omr_processor.dart';

/// Diagnostic tool. Pick or shoot any filled sheet and see, zoomed in,
/// exactly where the app sampled each bubble and what it read. If the
/// circles are sitting off the printed bubbles, calibration is the problem;
/// if they're centred but reading wrong, it's a lighting/pen issue. Either
/// way this tells you which, instead of guessing.
class DetectionTestScreen extends StatefulWidget {
  final int examId;
  const DetectionTestScreen({super.key, required this.examId});

  @override
  State<DetectionTestScreen> createState() => _DetectionTestScreenState();
}

class _DetectionTestScreenState extends State<DetectionTestScreen> {
  Exam? _exam;
  OmrScanOutcome? _outcome;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    DBHelper.instance.getExam(widget.examId).then((e) => setState(() => _exam = e));
  }

  Future<void> _run(ImageSource source) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final picked = await ImagePicker().pickImage(source: source, imageQuality: 95);
      if (picked == null) {
        setState(() => _busy = false);
        return;
      }
      final outcome = await OmrProcessor.scan(File(picked.path), _exam!);
      setState(() {
        _outcome = outcome;
        _error = outcome.failureReason;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final outcome = _outcome;
    return Scaffold(
      appBar: AppBar(title: const Text('Test Detection')),
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
                if (outcome != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    color: Colors.indigo.withOpacity(0.06),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Confidence: ${(outcome.confidence * 100).round()}%',
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text('Roll number read: ${outcome.rollNumber ?? "could not read"}'),
                        Text('Detected marks on ${outcome.marked.values.where((v) => v.isNotEmpty).length} question(s)'),
                        if (outcome.ambiguousQuestions.isNotEmpty)
                          Text('Borderline: Q${outcome.ambiguousQuestions.join(", Q")}',
                              style: const TextStyle(color: Colors.orange, fontSize: 12)),
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
                      'Pinch to zoom right in.\n'
                      'Blue boxes = the printed timing marks the app locked onto.\n'
                      'Circles should sit exactly on the printed bubbles.\n'
                      'Green = read filled · Red = read empty · Yellow = borderline',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ] else
                  const Expanded(
                    child: Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'Take or pick a photo of a filled answer sheet.\n\n'
                          'You will see the registration marks the app locked onto and '
                          'exactly where every bubble was sampled.',
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
