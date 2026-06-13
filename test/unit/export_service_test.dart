import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:qlct/models/transaction.dart';
import 'package:qlct/services/export_service.dart';

class _MockPathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _MockPathProvider(this.tempPath);
  final String tempPath;
  @override
  Future<String?> getApplicationDocumentsPath() async => tempPath;
}

Transaction _tx({
  String id = 't1',
  int amount = 50000,
  String category = 'Cà phê',
  String categoryId = 'coffee',
  String emoji = '☕',
  DateTime? date,
  String note = 'sáng',
}) {
  return Transaction(
    id: id,
    amount: amount,
    category: category,
    categoryId: categoryId,
    emoji: emoji,
    date: date ?? DateTime(2026, 6, 13, 8, 30),
    note: note,
  );
}

void main() {
  late Directory tempDir;
  late ExportService service;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('export_service_test_');
    PathProviderPlatform.instance = _MockPathProvider(tempDir.path);
    service = ExportService();
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  test('exportToCsv writes header + rows in date DESC order', () async {
    final older = _tx(id: 'a', date: DateTime(2026, 6, 10, 9));
    final newer = _tx(id: 'b', date: DateTime(2026, 6, 13, 8, 30), category: 'Ăn trưa');
    final middle = _tx(id: 'c', date: DateTime(2026, 6, 12, 12), category: 'Xăng');

    final file = await service.exportToCsv([older, newer, middle]);

    final csv = await file.readAsString();
    final lines = const LineSplitter().convert(csv);
    // header + 3 rows
    expect(lines.length, 4);
    expect(lines.first, 'Ngày,Danh mục,Số tiền (₫),Ghi chú');
    // newer (b, 13/06) should come before middle (c, 12/06) before older (a, 10/06)
    expect(lines[1], contains('Ăn trưa'));
    expect(lines[2], contains('Xăng'));
    expect(lines[3], contains('Cà phê'));
  });

  test('exportToCsv escapes commas/quotes/newlines in note', () async {
    final messy = _tx(
      id: 'm',
      note: 'có "dấu phẩy", và\nxuống dòng',
    );
    final file = await service.exportToCsv([messy]);
    final csv = await file.readAsString();
    // CSV field with comma, quote, or newline must be quoted
    expect(csv, contains('"có ""dấu phẩy"", và'));
    expect(csv, contains('xuống dòng"'));
  });

  test('exportToCsv handles empty list (header only)', () async {
    final file = await service.exportToCsv([]);
    final csv = await file.readAsString();
    final lines = const LineSplitter().convert(csv);
    expect(lines.length, 1);
    expect(lines.first, 'Ngày,Danh mục,Số tiền (₫),Ghi chú');
  });

  test('exportToJson produces valid JSON with exportDate + transactions', () async {
    final t = _tx(id: 'j1');
    final file = await service.exportToJson([t]);
    final raw = await file.readAsString();
    final decoded = jsonDecode(raw) as Map<String, dynamic>;

    expect(decoded['exportDate'], isA<String>());
    expect(decoded['transactions'], isA<List>());
    final txs = decoded['transactions'] as List;
    expect(txs.length, 1);
    expect(txs.first['id'], 'j1');
    expect(txs.first['categoryId'], 'coffee');
  });

  test('exportToJson sorts by date DESC', () async {
    final older = _tx(id: 'a', date: DateTime(2026, 6, 10));
    final newer = _tx(id: 'b', date: DateTime(2026, 6, 13));
    final file = await service.exportToJson([older, newer]);
    final decoded = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    final txs = (decoded['transactions'] as List).cast<Map<String, dynamic>>();
    expect(txs.map((m) => m['id']).toList(), ['b', 'a']);
  });

  test('exportToJson round-trips via Transaction.fromJson', () async {
    final original = _tx(id: 'rt', note: 'round-trip');
    final file = await service.exportToJson([original]);
    final decoded = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    final txs = (decoded['transactions'] as List).cast<Map<String, dynamic>>();
    final restored = Transaction.fromJson(txs.first);

    expect(restored.id, original.id);
    expect(restored.amount, original.amount);
    expect(restored.category, original.category);
    expect(restored.categoryId, original.categoryId);
    expect(restored.emoji, original.emoji);
    expect(restored.date, original.date);
    expect(restored.note, original.note);
  });

  test('getExportDirectory returns path_provider path', () async {
    final dir = await service.getExportDirectory();
    expect(dir, tempDir.path);
  });
}
