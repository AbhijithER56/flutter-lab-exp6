import 'dart:io';

import 'package:flutter_experiment_6_data_persistence_sqlite/database_helper.dart';
import 'package:flutter_experiment_6_data_persistence_sqlite/student_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Directory tempDir;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('student_db_test');
    DatabaseHelper.pathOverride =
        p.join(tempDir.path, DatabaseHelper.databaseName);
  });

  tearDown(() async {
    await DatabaseHelper.instance.close();
    await tempDir.delete(recursive: true);
  });

  const Student priya = Student(
    name: 'Priya Sharma',
    registerNumber: 'RA2211003010123',
    department: 'Computer Science',
    email: 'priya@example.com',
  );
  const Student arjun = Student(
    name: 'Arjun Kumar',
    registerNumber: 'RA2211003010124',
    department: 'Information Technology',
    email: 'arjun@example.com',
  );

  test('CREATE: students table is created with the required columns',
      () async {
    final Database db = await DatabaseHelper.instance.database;
    final List<Map<String, Object?>> columns =
        await db.rawQuery('PRAGMA table_info(students)');

    expect(
      columns.map((c) => '${c['name']} ${c['type']} ${c['notnull']}'),
      [
        'id INTEGER 0',
        'name TEXT 1',
        'register_number TEXT 1',
        'department TEXT 1',
        'email TEXT 1',
      ],
    );
    expect(columns.first['pk'], 1);
  });

  test('READ: empty table returns no records', () async {
    expect(await DatabaseHelper.instance.getAllStudents(), isEmpty);
  });

  test('CREATE + READ: inserted record is returned by SELECT', () async {
    final int id = await DatabaseHelper.instance.insertStudent(priya);
    final List<Student> students =
        await DatabaseHelper.instance.getAllStudents();

    expect(id, 1);
    expect(students, hasLength(1));
    expect(students.single.id, 1);
    expect(students.single.name, priya.name);
    expect(students.single.registerNumber, priya.registerNumber);
    expect(students.single.department, priya.department);
    expect(students.single.email, priya.email);
  });

  test('multiple records get AUTOINCREMENT ids, newest first', () async {
    await DatabaseHelper.instance.insertStudent(priya);
    await DatabaseHelper.instance.insertStudent(arjun);

    final List<Student> students =
        await DatabaseHelper.instance.getAllStudents();
    expect(students.map((s) => s.id), [2, 1]);
    expect(students.map((s) => s.name), ['Arjun Kumar', 'Priya Sharma']);
  });

  test('records persist after the database is closed and reopened',
      () async {
    await DatabaseHelper.instance.insertStudent(priya);
    await DatabaseHelper.instance.insertStudent(arjun);
    await DatabaseHelper.instance.close(); // simulate app restart

    expect(
      File(DatabaseHelper.pathOverride!).existsSync(),
      isTrue,
      reason: 'student_database.db must exist on disk',
    );
    final List<Student> students =
        await DatabaseHelper.instance.getAllStudents();
    expect(students, hasLength(2));
  });
}
