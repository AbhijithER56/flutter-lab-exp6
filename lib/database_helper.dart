import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import 'student_model.dart';

/// Manages the SQLite database `student_database.db` and the `students` table.
///
/// The platform-specific [databaseFactory] (native SQLite on Android,
/// SQLite compiled to WebAssembly on Chrome) is selected in `main.dart`.
class DatabaseHelper {
  static const String databaseName = 'student_database.db';
  static const String tableName = 'students';
  static const int databaseVersion = 1;

  DatabaseHelper._internal();

  /// Single shared instance used by the whole app.
  static final DatabaseHelper instance = DatabaseHelper._internal();

  /// Optional full path override, used by unit tests.
  static String? pathOverride;

  Database? _database;

  /// Opens the database on first use and returns the same connection after.
  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final String path =
        pathOverride ?? join(await getDatabasesPath(), databaseName);
    return openDatabase(path, version: databaseVersion, onCreate: _onCreate);
  }

  /// CREATE: runs only the first time the database file is created.
  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $tableName (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        register_number TEXT NOT NULL,
        department TEXT NOT NULL,
        email TEXT NOT NULL
      )
    ''');
  }

  /// CREATE: inserts a student record and returns the new row id.
  Future<int> insertStudent(Student student) async {
    final Database db = await database;
    return db.rawInsert(
      'INSERT INTO $tableName (name, register_number, department, email) '
      'VALUES (?, ?, ?, ?)',
      [
        student.name,
        student.registerNumber,
        student.department,
        student.email,
      ],
    );
  }

  /// READ: retrieves every student record, newest first.
  Future<List<Student>> getAllStudents() async {
    final Database db = await database;
    final List<Map<String, Object?>> rows =
        await db.rawQuery('SELECT * FROM $tableName ORDER BY id DESC');
    return rows.map(Student.fromMap).toList();
  }

  /// Closes the connection (used by tests to simulate an app restart).
  Future<void> close() async {
    await _database?.close();
    _database = null;
  }
}
