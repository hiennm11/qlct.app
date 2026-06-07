import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:qlct/data/datasources/quick_template_local_datasource.dart';
import 'package:qlct/models/quick_template.dart';
import 'package:qlct/viewmodels/quick_template_viewmodel.dart';

class MockQuickTemplateDataSource extends Mock
    implements QuickTemplateLocalDataSource {}

void main() {
  late MockQuickTemplateDataSource mockDs;
  late QuickTemplateViewModel vm;

  QuickTemplate makeTemplate({
    String id = 't-1',
    String title = 'Cơm trưa',
    int amount = 35000,
    String categoryName = 'Ăn ngoài',
    String note = '',
    bool isPinned = false,
    int usageCount = 0,
    DateTime? lastUsedAt,
  }) {
    final now = DateTime(2026, 6, 7, 10);
    return QuickTemplate(
      id: id,
      title: title,
      amount: amount,
      categoryName: categoryName,
      note: note,
      isPinned: isPinned,
      usageCount: usageCount,
      lastUsedAt: lastUsedAt,
      createdAt: now,
      updatedAt: now,
    );
  }

  setUpAll(() {
    registerFallbackValue(makeTemplate());
    registerFallbackValue(DateTime(2026, 6, 7));
  });

  setUp(() {
    mockDs = MockQuickTemplateDataSource();
    when(() => mockDs.getAll()).thenAnswer((_) async => []);
    vm = QuickTemplateViewModel(mockDs);
  });

  group('load', () {
    test('loads templates from data source', () async {
      final t = makeTemplate();
      when(() => mockDs.getAll()).thenAnswer((_) async => [t]);
      await vm.forceReload();
      expect(vm.templates.length, 1);
      expect(vm.templates.first.id, 't-1');
    });

    test('sets error message on failure', () async {
      when(() => mockDs.getAll()).thenThrow(Exception('db error'));
      await vm.forceReload();
      expect(vm.errorMessage, isNotNull);
    });
  });

  group('create', () {
    test('inserts a new template when not a duplicate', () async {
      when(() => mockDs.existsExactDuplicate(
            title: any(named: 'title'),
            amount: any(named: 'amount'),
            categoryName: any(named: 'categoryName'),
            note: any(named: 'note'),
            excludeId: any(named: 'excludeId'),
          )).thenAnswer((_) async => false);
      when(() => mockDs.insert(any())).thenAnswer((_) async {});

      final result = await vm.create(
        title: 'Cà phê sáng',
        amount: 25000,
        categoryName: 'Cà phê',
      );

      expect(result.success, isTrue);
      expect(result.duplicate, isFalse);
      expect(result.template, isNotNull);
      verify(() => mockDs.insert(any<QuickTemplate>())).called(1);
    });

    test('returns duplicate result without insert', () async {
      when(() => mockDs.existsExactDuplicate(
            title: any(named: 'title'),
            amount: any(named: 'amount'),
            categoryName: any(named: 'categoryName'),
            note: any(named: 'note'),
            excludeId: any(named: 'excludeId'),
          )).thenAnswer((_) async => true);

      final result = await vm.create(
        title: 'Cà phê sáng',
        amount: 25000,
        categoryName: 'Cà phê',
      );

      expect(result.success, isFalse);
      expect(result.duplicate, isTrue);
      verifyNever(() => mockDs.insert(any()));
    });
  });

  group('update', () {
    test('updates when not duplicate of another row', () async {
      final t = makeTemplate(id: 't-1');
      when(() => mockDs.existsExactDuplicate(
            title: any(named: 'title'),
            amount: any(named: 'amount'),
            categoryName: any(named: 'categoryName'),
            note: any(named: 'note'),
            excludeId: any(named: 'excludeId'),
          )).thenAnswer((_) async => false);
      when(() => mockDs.update(any())).thenAnswer((_) async {});

      final result = await vm.update(t.copyWith(title: 'New'));

      expect(result.success, isTrue);
      verify(() => mockDs.update(any<QuickTemplate>())).called(1);
    });

    test('passes excludeId to duplicate check on update', () async {
      final t = makeTemplate(id: 't-1');
      when(() => mockDs.existsExactDuplicate(
            title: any(named: 'title'),
            amount: any(named: 'amount'),
            categoryName: any(named: 'categoryName'),
            note: any(named: 'note'),
            excludeId: any(named: 'excludeId'),
          )).thenAnswer((_) async => false);
      when(() => mockDs.update(any())).thenAnswer((_) async {});

      await vm.update(t.copyWith(title: 'New'));

      verify(() => mockDs.existsExactDuplicate(
            title: 'New',
            amount: t.amount,
            categoryName: t.categoryName,
            note: t.note,
            excludeId: 't-1',
          )).called(1);
    });

    test('returns duplicate when matching another row', () async {
      final t = makeTemplate(id: 't-1');
      when(() => mockDs.existsExactDuplicate(
            title: any(named: 'title'),
            amount: any(named: 'amount'),
            categoryName: any(named: 'categoryName'),
            note: any(named: 'note'),
            excludeId: any(named: 'excludeId'),
          )).thenAnswer((_) async => true);

      final result = await vm.update(t.copyWith(title: 'New'));

      expect(result.duplicate, isTrue);
      verifyNever(() => mockDs.update(any()));
    });
  });

  group('delete', () {
    test('deletes and returns true on success', () async {
      when(() => mockDs.delete('t-1')).thenAnswer((_) async {});
      final result = await vm.delete('t-1');
      expect(result, isTrue);
      verify(() => mockDs.delete('t-1')).called(1);
    });

    test('returns false on error', () async {
      when(() => mockDs.delete('t-1')).thenThrow(Exception('db'));
      final result = await vm.delete('t-1');
      expect(result, isFalse);
      expect(vm.errorMessage, isNotNull);
    });
  });

  group('togglePin', () {
    test('flips isPinned and updates', () async {
      final t = makeTemplate(id: 't-1', isPinned: false);
      when(() => mockDs.getAll()).thenAnswer((_) async => [t]);
      when(() => mockDs.existsExactDuplicate(
            title: any(named: 'title'),
            amount: any(named: 'amount'),
            categoryName: any(named: 'categoryName'),
            note: any(named: 'note'),
            excludeId: any(named: 'excludeId'),
          )).thenAnswer((_) async => false);
      when(() => mockDs.update(any())).thenAnswer((_) async {});

      // Force the list to be loaded synchronously for this test.
      await vm.forceReload();

      final ok = await vm.togglePin('t-1');
      expect(ok, isTrue);
      verify(() => mockDs.update(any(that: isA<QuickTemplate>()))).called(1);
    });
  });

  group('markUsed', () {
    test('calls data source markUsed and reloads', () async {
      final t = makeTemplate(id: 't-1');
      when(() => mockDs.getAll()).thenAnswer((_) async => [t]);
      when(() => mockDs.markUsed('t-1', any())).thenAnswer((_) async {});

      await vm.markUsed('t-1');

      verify(() => mockDs.markUsed('t-1', any())).called(1);
      expect(vm.templates, isNotEmpty);
    });
  });

  group('clearError', () {
    test('clears the error message', () async {
      when(() => mockDs.delete(any())).thenThrow(Exception('err'));
      await vm.delete('t-1');
      expect(vm.errorMessage, isNotNull);

      vm.clearError();
      expect(vm.errorMessage, isNull);
    });
  });
}