import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import '../db/db_helper.dart';
import '../models/exam.dart';
import '../models/student_result.dart';
import '../services/omr_processor.dart';
import '../services/sheet_template.dart';
import 'review_screen.dart';

/// Live camera scanner: shows a real-time preview with a guide frame sized
/// to the sheet's proportions, detects when the frame has gone
/// still (the user has the sheet held steady inside the guide) and
/// auto-captures — no need to leave the app or tap through a system camera
/// UI for every single sheet. Manual capture is always available too.
class LiveScanScreen extends StatefulWidget {
  final int examId;
  const LiveScanScreen({super.key, required this.examId});

  @override
  State<LiveScanScreen> createState() => _LiveScanScreenState();
}

class _LiveScanScreenState extends State<LiveScanScreen>
    with WidgetsBindingObserver {
  Exam? _exam;
  CameraController? _controller;
  bool _initializing = true;
  String? _permissionError;

  bool _autoCapture = true;
  bool _torchOn = false;
  bool _capturing = false;
  int _scannedCount = 0;

  // stability detection
  List<int>? _prevSample;
  int _stableFrames = 0;
  static const int _stableFramesNeeded = 14;
  static const double _stillnessThreshold = 3.0;
  double _stability = 0; // 0-1 for UI ring

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final exam = await DBHelper.instance.getExam(widget.examId);
    setState(() => _exam = exam);

    final status = await Permission.camera.request();
    if (!status.isGranted) {
      setState(() {
        _permissionError =
            'Camera permission is required to scan sheets. Enable it from app settings.';
        _initializing = false;
      });
      return;
    }

    final cameras = await availableCameras();
    if (cameras.isEmpty) {
      setState(() {
        _permissionError = 'No camera found on this device.';
        _initializing = false;
      });
      return;
    }
    final backCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first);
    final controller = CameraController(
      backCamera,
      ResolutionPreset.veryHigh,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );
    await controller.initialize();
    _controller = controller;
    setState(() => _initializing = false);
    _startStream();
  }

  void _startStream() {
    _controller?.startImageStream(_onFrame);
  }

  Future<void> _stopStream() async {
    if (_controller?.value.isStreamingImages == true) {
      await _controller!.stopImageStream();
    }
  }

  void _onFrame(CameraImage image) {
    if (_capturing || !_autoCapture) return;
    final bytes = image.planes.first.bytes;
    const stride = 97; // prime stride keeps sampling cheap & roughly uniform
    final sample = <int>[];
    for (int i = 0; i < bytes.length; i += stride) {
      sample.add(bytes[i]);
    }

    if (_prevSample != null && _prevSample!.length == sample.length) {
      double diffSum = 0;
      for (int i = 0; i < sample.length; i++) {
        diffSum += (sample[i] - _prevSample![i]).abs();
      }
      final avgDiff = diffSum / sample.length;
      if (avgDiff < _stillnessThreshold) {
        _stableFrames++;
      } else {
        _stableFrames = 0;
      }
      final stability = (_stableFrames / _stableFramesNeeded).clamp(0.0, 1.0);
      if (mounted && (stability - _stability).abs() > 0.05) {
        setState(() => _stability = stability);
      }
      if (_stableFrames >= _stableFramesNeeded) {
        _stableFrames = 0;
        _captureAndProcess();
      }
    }
    _prevSample = sample;
  }

  Future<void> _toggleTorch() async {
    if (_controller == null) return;
    _torchOn = !_torchOn;
    await _controller!.setFlashMode(_torchOn ? FlashMode.torch : FlashMode.off);
    setState(() {});
  }

  Future<void> _captureAndProcess() async {
    if (_capturing || _controller == null || !_controller!.value.isInitialized)
      return;
    setState(() => _capturing = true);
    try {
      await _stopStream();
      final xfile = await _controller!.takePicture();
      final file = File(xfile.path);
      final outcome = await OmrProcessor.scan(file, _exam!);
      if (!mounted) return;

      if (!outcome.registered) {
        await showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Could not read the sheet'),
            content: Text(outcome.failureReason!),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Try again'))
            ],
          ),
        );
        return;
      }

      // Review confirms (and corrects) the auto-read marks and roll number,
      // so what gets stored is exact.
      final confirmed = await Navigator.push<ReviewResult>(
        context,
        MaterialPageRoute(
            builder: (_) => ReviewScreen(exam: _exam!, outcome: outcome)),
      );
      if (confirmed == null) return; // user chose Rescan

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
      if (!mounted) return;
      setState(() => _scannedCount++);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 2),
          backgroundColor: Colors.green[700],
          content: Text(
              'Roll ${confirmed.rollNumber} saved · $correct correct — ready for the next sheet'),
        ),
      );
    } catch (err) {
      if (mounted) {
        await showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Scan failed'),
            content: Text(err.toString()),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'))
            ],
          ),
        );
      }
    } finally {
      _prevSample = null;
      _stableFrames = 0;
      if (mounted) {
        setState(() {
          _capturing = false;
          _stability = 0;
        });
        _startStream();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _stopStream();
    } else if (state == AppLifecycleState.resumed) {
      _startStream();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(_exam?.name ?? 'Scan'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _controller == null ? null : _toggleTorch,
            icon: Icon(_torchOn ? Icons.flash_on : Icons.flash_off),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
                child: Text('Scanned: $_scannedCount',
                    style: const TextStyle(fontWeight: FontWeight.bold))),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_permissionError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_permissionError!,
              style: const TextStyle(color: Colors.white),
              textAlign: TextAlign.center),
        ),
      );
    }
    if (_initializing ||
        _controller == null ||
        !_controller!.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }
    final aspect = kDefaultSheetTemplate.pageAspectRatio;

    return Stack(
      fit: StackFit.expand,
      children: [
        Center(child: CameraPreview(_controller!)),
        // dim mask + guide frame
        Center(
          child: AspectRatio(
            aspectRatio: aspect,
            child: FractionallySizedBox(
              widthFactor: 0.94,
              heightFactor: 0.94,
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Color.lerp(
                        Colors.white70, Colors.greenAccent, _stability)!,
                    width: 3,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          top: 16,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20)),
              child: Text(
                _capturing
                    ? 'Capturing…'
                    : _autoCapture
                        ? 'Fit the WHOLE sheet in the frame and hold still'
                        : 'Manual mode — tap the button to capture',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ),
        ),
        if (_capturing) const Center(child: CircularProgressIndicator()),
        Positioned(
          bottom: 24,
          left: 0,
          right: 0,
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Auto-capture',
                      style: TextStyle(color: Colors.white)),
                  Switch(
                    value: _autoCapture,
                    onChanged: (v) => setState(() => _autoCapture = v),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              FloatingActionButton.large(
                heroTag: 'manual-capture',
                onPressed: _capturing ? null : _captureAndProcess,
                child: const Icon(Icons.camera_alt),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
