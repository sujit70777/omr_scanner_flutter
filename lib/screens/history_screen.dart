import 'package:flutter/material.dart';
import '../db/db_helper.dart';
import '../models/exam.dart';
import '../models/student_result.dart';
import '../services/entitlement_service.dart';
import '../services/results_exporter.dart';
import 'paywall_screen.dart';
import 'student_detail_screen.dart';

class HistoryScreen extends StatefulWidget {
  final int examId;
  final String examName;
  const HistoryScreen({super.key, required this.examId, required this.examName});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  Exam? _exam;
  List<StudentResult> _results = [];
  bool _loading = true;
  bool _exporting = false;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final exam = await DBHelper.instance.getExam(widget.examId);
    final results = await DBHelper.instance.getResultsForExam(widget.examId);
    setState(() {
      _exam = exam;
      _results = results;
      _loading = false;
    });
  }

  Future<void> _export(ExportFormat format) async {
    if (_exam == null || _results.isEmpty || _exporting) return;
    final ent = EntitlementService.instance;
    if (!ent.canExport(format)) {
      final ok = await PaywallScreen.open(
        context,
        reason: 'Excel and PDF export are Premium. CSV stays free.',
      );
      if (!ok || !ent.canExport(format)) return;
    }
    setState(() => _exporting = true);
    try {
      await ResultsExporter.export(
        exam: _exam!,
        results: _results,
        format: format,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchCtrl.text.trim().toLowerCase();
    final filtered = query.isEmpty
        ? _results
        : _results.where((r) => r.rollNumber.toLowerCase().contains(query)).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.examName} · History'),
        actions: [
          if (_exporting)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            PopupMenuButton<ExportFormat>(
              tooltip: 'Export results',
              enabled: !_loading && _results.isNotEmpty,
              icon: const Icon(Icons.ios_share),
              onSelected: _export,
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: ExportFormat.csv,
                  child: ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.table_chart_outlined),
                    title: Text('Export CSV'),
                  ),
                ),
                PopupMenuItem(
                  value: ExportFormat.excel,
                  child: ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.grid_on),
                    title: const Text('Export Excel'),
                    trailing: EntitlementService.instance.isPremium
                        ? null
                        : const Icon(Icons.lock_outline, size: 18),
                  ),
                ),
                PopupMenuItem(
                  value: ExportFormat.pdf,
                  child: ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.picture_as_pdf_outlined),
                    title: const Text('Export PDF'),
                    trailing: EntitlementService.instance.isPremium
                        ? null
                        : const Icon(Icons.lock_outline, size: 18),
                  ),
                ),
              ],
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                hintText: 'Search by roll number',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                    ? const Center(
                        child: Text('No scanned results yet',
                            style: TextStyle(color: Colors.grey)))
                    : ListView.separated(
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final r = filtered[i];
                          return ListTile(
                            leading: CircleAvatar(
                                child: Text(r.rollNumber.isNotEmpty
                                    ? r.rollNumber[0]
                                    : '?')),
                            title: Text('Roll: ${r.rollNumber}',
                                style: const TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: Text(
                                'Correct: ${r.correctCount} · Wrong: ${r.wrongCount} · Blank: ${r.unattemptedCount}\nScanned: ${r.scannedAt}'),
                            isThreeLine: true,
                            trailing: Text(
                              r.score == r.score.roundToDouble()
                                  ? r.score.toStringAsFixed(0)
                                  : r.score.toStringAsFixed(1),
                              style: const TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            onTap: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => StudentDetailScreen(
                                      resultId: r.id!, examId: widget.examId),
                                ),
                              );
                              _load();
                            },
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
