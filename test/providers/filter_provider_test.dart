import 'package:flutter_test/flutter_test.dart';
import 'package:interview_todos/providers/filter_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  group('doneFilterProvider', () {
    test('initial state is DoneFilter.all', () {
      // Arrange
      final container = ProviderContainer();
      
      // Act
      final filter = container.read(doneFilterProvider);
      
      // Assert
      expect(filter, DoneFilter.all);
    });

    test('can update done filter', () {
      // Arrange
      final container = ProviderContainer();
      
      // Act
      container.read(doneFilterProvider.notifier).state = DoneFilter.done;
      
      // Assert
      expect(container.read(doneFilterProvider), DoneFilter.done);
    });
  });

  group('todoCategoryFilterProvider', () {
    test('initial state is TodoCategoryFilter.all', () {
      // Arrange
      final container = ProviderContainer();
      
      // Act
      final filter = container.read(todoCategoryFilterProvider);
      
      // Assert
      expect(filter, TodoCategoryFilter.all);
    });

    test('can update category filter', () {
      // Arrange
      final container = ProviderContainer();
      
      // Act
      container.read(todoCategoryFilterProvider.notifier).state = TodoCategoryFilter.work;
      
      // Assert
      expect(container.read(todoCategoryFilterProvider), TodoCategoryFilter.work);
    });
  });
}
