import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/exam.dart';
import '../models/student_result.dart';

class DBHelper {
  DBHelper._();
  static final DBHelper instance = DBHelper._();
  Database? _db;

  Future<Database> get db async {
    if (_db != null) return _db!;
    _db = await _init();
    return _db!;
  }

  Future<Database> _init() async {
    final path = join(await getDatabasesPath(), 'omr_scanner.db');
    return openDatabase(
      path,
      version: 3,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE exams(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            totalQuestions INTEGER NOT NULL,
            optionsCount INTEGER NOT NULL,
            createdAt TEXT NOT NULL,
            answerKeyJson TEXT NOT NULL,
            calibrationJson TEXT NOT NULL,
            sheetAspectRatio REAL,
            settingsJson TEXT NOT NULL DEFAULT '{}'
          )
        ''');
        await db.execute('''
          CREATE TABLE results(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            examId INTEGER NOT NULL,
            rollNumber TEXT NOT NULL,
            markedJson TEXT NOT NULL,
            correctCount INTEGER NOT NULL,
            wrongCount INTEGER NOT NULL,
            unattemptedCount INTEGER NOT NULL,
            score REAL NOT NULL,
            scannedAt TEXT NOT NULL,
            FOREIGN KEY(examId) REFERENCES exams(id) ON DELETE CASCADE
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE exams ADD COLUMN sheetAspectRatio REAL');
        }
        if (oldVersion < 3) {
          await db.execute(
              "ALTER TABLE exams ADD COLUMN settingsJson TEXT NOT NULL DEFAULT '{}'");
        }
      },
    );
  }

  // ---------------- Exams ----------------
  Future<int> insertExam(Exam e) async {
    final database = await db;
    return database.insert('exams', e.toMap()..remove('id'));
  }

  Future<void> updateExam(Exam e) async {
    final database = await db;
    await database.update('exams', e.toMap(), where: 'id = ?', whereArgs: [e.id]);
  }

  Future<void> deleteExam(int id) async {
    final database = await db;
    await database.delete('results', where: 'examId = ?', whereArgs: [id]);
    await database.delete('exams', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Exam>> getExams() async {
    final database = await db;
    final rows = await database.query('exams', orderBy: 'id DESC');
    return rows.map((r) => Exam.fromMap(r)).toList();
  }

  Future<Exam?> getExam(int id) async {
    final database = await db;
    final rows = await database.query('exams', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return Exam.fromMap(rows.first);
  }

  // ---------------- Results ----------------
  Future<int> insertResult(StudentResult r) async {
    final database = await db;
    return database.insert('results', r.toMap()..remove('id'));
  }

  Future<StudentResult?> getResult(int id) async {
    final database = await db;
    final rows = await database.query('results', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return StudentResult.fromMap(rows.first);
  }

  Future<List<StudentResult>> getResultsForExam(int examId) async {
    final database = await db;
    final rows = await database.query('results', where: 'examId = ?', whereArgs: [examId], orderBy: 'id DESC');
    return rows.map((r) => StudentResult.fromMap(r)).toList();
  }

  Future<void> deleteResult(int id) async {
    final database = await db;
    await database.delete('results', where: 'id = ?', whereArgs: [id]);
  }
}
