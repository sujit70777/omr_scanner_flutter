import 'package:flutter/material.dart';
import '../db/db_helper.dart';
import '../models/student_result.dart';
import 'student_detail_screen.dart';

class HistoryScreen extends StatefulWidget {
  final int examId;
  final String examName;
  const HistoryScreen({super.key, required this.examId, required this.examName});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<StudentResult> _results = [];
  bool _loading = true;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final results = await DBHelper.instance.getResultsForExam(widget.examId);
    setState(() {
      _results = results;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchCtrl.text.trim().toLowerCase();
    final filtered = query.isEmpty ? _results : _results.where((r) => r.rollNumber.toLowerCase().contains(query)).toList();

    return Scaffold(
      appBar: AppBar(title: Text('${widget.examName} · History')),
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
                    ? const Center(child: Text('No scanned results yet', style: TextStyle(color: Colors.grey)))
                    : ListView.separated(
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final r = filtered[i];
                          return ListTile(
                            leading: CircleAvatar(child: Text(r.rollNumber.isNotEmpty ? r.rollNumber[0] : '?')),
                            title: Text('Roll: ${r.rollNumber}', style: const TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: Text('Correct: ${r.correctCount} · Wrong: ${r.wrongCount} · Blank: ${r.unattemptedCount}\nScanned: ${r.scannedAt}'),
                            isThreeLine: true,
                            trailing: Text('${r.score.toStringAsFixed(0)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            onTap: () async {
                              await Navigator.push(context, MaterialPageRoute(builder: (_) => StudentDetailScreen(resultId: r.id!, examId: widget.examId)));
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
