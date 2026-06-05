import '../../models/recurring_transaction.dart';

abstract class RecurringLocalDataSource {
  Future<List<RecurringTransaction>> getAll();
  Future<void> insert(RecurringTransaction recurring);
  Future<void> update(RecurringTransaction recurring);
  Future<void> delete(String id);
  Future<List<RecurringTransaction>> getActiveDue(DateTime now);
  Future<void> updateNextRunAt(String id, DateTime nextRunAt);

  /// Bulk insert recurring transactions using batch for performance
  Future<void> bulkInsert(List<RecurringTransaction> recurrings);
}
