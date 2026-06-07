// ADR-0019 review fix: verifies _onCreate creates quick_templates table + indexes.
// Without this fix, new installs (onCreate path, DB v8) would miss the table.
//
// Uses testPathOverride to give each test a unique file path, avoiding the
// FFI isolate locking the default qlct.db from previous test runs.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart' hide Transaction;
import 'package:qlct/data/database/database_helper.dart';

void main() {
  late String dbPath;
  late Directory tempDir;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('dbhelper_test_');
    final dbFileName =
        'qlct_test_${DateTime.now().microsecondsSinceEpoch}.db';
    dbPath = p.join(tempDir.path, dbFileName);
  });

  tearDown(() async {
    try {
      tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  test('fresh DB via _onCreate includes quick_templates table', () async {
    final dbHelper = DatabaseHelper();
    dbHelper.testPathOverride = dbPath;
    await dbHelper.database;

    final db = await dbHelper.rawDatabase;

    // Verify table exists
    final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='quick_templates'");
    expect(tables.length, 1,
        reason: 'quick_templates table must exist after _onCreate');

    // Verify indexes exist
    final indexes = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='index' AND tbl_name='quick_templates'");
    final indexNames = indexes.map((r) => r['name'] as String).toList();
    expect(indexNames, contains('idx_quick_templates_pinned'),
        reason: 'pinned index must exist');
    expect(indexNames, contains('idx_quick_templates_usage'),
        reason: 'usage index must exist');

    await dbHelper.close();
  });

  test('fresh DB via _onCreate includes all required tables', () async {
    final dbHelper = DatabaseHelper();
    dbHelper.testPathOverride = dbPath;
    await dbHelper.database;
    final db = await dbHelper.rawDatabase;

    final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name");
    final tableNames = tables.map((r) => r['name'] as String).toList();

    expect(tableNames, contains('transactions'));
    expect(tableNames, contains('budgets'));
    expect(tableNames, contains('recurring_transactions'));
    expect(tableNames, contains('quick_templates'));

    await dbHelper.close();
  });
}