import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_experiment_6_data_persistence_sqlite/database_helper.dart';
import 'package:flutter_experiment_6_data_persistence_sqlite/main.dart';
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
    tempDir = await Directory.systemTemp.createTemp('student_widget_test');
    DatabaseHelper.pathOverride =
        p.join(tempDir.path, DatabaseHelper.databaseName);
  });

  tearDown(() async {
    await DatabaseHelper.instance.close();
    await tempDir.delete(recursive: true);
  });

  Finder field(String label) => find.widgetWithText(TextFormField, label);

  Future<void> fillForm(
    WidgetTester tester, {
    String name = 'Priya Sharma',
    String reg = 'RA2211003010123',
    String dept = 'Computer Science',
    String email = 'priya@example.com',
  }) async {
    await tester.enterText(field('Student Name'), name);
    await tester.enterText(field('Registration Number'), reg);
    await tester.enterText(field('Department'), dept);
    await tester.enterText(field('Email Address'), email);
  }

  Future<void> tapSave(WidgetTester tester) async {
    await tester.ensureVisible(find.text('Save Student'));
    await tester.tap(find.text('Save Student'));
    await tester.pump();
  }

  testWidgets('Add Student screen shows all fields and buttons',
      (tester) async {
    await tester.pumpWidget(const StudentRecordApp());

    expect(find.text('Add Student'), findsOneWidget);
    expect(field('Student Name'), findsOneWidget);
    expect(field('Registration Number'), findsOneWidget);
    expect(field('Department'), findsOneWidget);
    expect(field('Email Address'), findsOneWidget);
    expect(find.text('Save Student'), findsOneWidget);
    expect(find.text('View Students'), findsOneWidget);
  });

  testWidgets('empty fields show validation errors', (tester) async {
    await tester.pumpWidget(const StudentRecordApp());
    await tapSave(tester);

    expect(find.text('Please enter the student name.'), findsOneWidget);
    expect(find.text('Please enter the registration number.'), findsOneWidget);
    expect(find.text('Please enter the department.'), findsOneWidget);
    expect(find.text('Please enter the email address.'), findsOneWidget);
  });

  testWidgets('invalid email is rejected and nothing is saved',
      (tester) async {
    await tester.pumpWidget(const StudentRecordApp());
    await fillForm(tester, email: 'priya@invalid');
    await tapSave(tester);

    expect(
      find.text('Enter a valid email address (e.g. name@example.com).'),
      findsOneWidget,
    );
    final rows = await tester
        .runAsync(() => DatabaseHelper.instance.getAllStudents());
    expect(rows, isEmpty);
  });

  testWidgets('valid student is saved, SnackBar shown and form cleared',
      (tester) async {
    await tester.pumpWidget(const StudentRecordApp());
    await fillForm(tester);

    await tester.runAsync(() async {
      await tester.tap(find.text('Save Student'));
      // Let the real SQLite INSERT complete.
      await Future<void>.delayed(const Duration(milliseconds: 500));
    });
    await tester.pumpAndSettle();

    expect(
      find.text('Priya Sharma saved successfully (ID: 1).'),
      findsOneWidget,
    );
    final TextFormField nameField = tester.widget(field('Student Name'));
    expect(nameField.controller!.text, isEmpty);
    expect(find.text('Please enter the student name.'), findsNothing);

    final rows = await tester
        .runAsync(() => DatabaseHelper.instance.getAllStudents());
    expect(rows!.single.registerNumber, 'RA2211003010123');
  });
}
