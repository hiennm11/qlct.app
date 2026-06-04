import '../models/recurring_transaction.dart';

abstract class RecurringRepository {
  Future<List<RecurringTransaction>> getAll();
  Future<void> insert(RecurringTransaction recurring);
  Future<void> update(RecurringTransaction recurring);
  Future<void> delete(String id);
  Future<List<RecurringTransaction>> getActiveDue(DateTime now);
  Future<void> updateNextRunAt(String id, DateTime nextRunAt);
}
