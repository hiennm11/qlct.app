import 'dart:io';
import 'dart:convert';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import '../models/transaction.dart';
import '../core/formatters.dart';

/// Service for exporting transaction data
class ExportService {
  /// Export transactions to CSV file
  Future<File> exportToCsv(List<Transaction> transactions) async {
    // Sort by date descending
    final sorted = [...transactions]..sort((a, b) => b.date.compareTo(a.date));

    // Create CSV data
    final List<List<dynamic>> rows = [
      ['Ngày', 'Danh mục', 'Số tiền (₫)', 'Ghi chú'],
    ];

    for (final transaction in sorted) {
      rows.add([
        DateFormatter.formatDateTime(transaction.date),
        transaction.category,
        transaction.amount.toString(),
        transaction.note,
      ]);
    }

    // Convert to CSV string
    final csvString = const ListToCsvConverter().convert(rows);

    // Save to file
    final directory = await getApplicationDocumentsDirectory();
    final fileName =
        'chi-tieu-${DateTime.now().toIso8601String().split('T')[0]}.csv';
    final file = File('${directory.path}/$fileName');
    await file.writeAsString(csvString, encoding: utf8);

    return file;
  }

  /// Export transactions to JSON file
  Future<File> exportToJson(List<Transaction> transactions) async {
    // Sort by date descending
    final sorted = [...transactions]..sort((a, b) => b.date.compareTo(a.date));

    // Create export data
    final exportData = {
      'exportDate': DateTime.now().toIso8601String(),
      'transactions': sorted.map((t) => t.toJson()).toList(),
    };

    // Convert to JSON string
    final jsonString = jsonEncode(exportData);

    // Save to file
    final directory = await getApplicationDocumentsDirectory();
    final fileName =
        'chi-tieu-${DateTime.now().toIso8601String().split('T')[0]}.json';
    final file = File('${directory.path}/$fileName');
    await file.writeAsString(jsonString);

    return file;
  }

  /// Get the export directory path
  Future<String> getExportDirectory() async {
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }
}
