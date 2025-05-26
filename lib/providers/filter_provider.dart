import 'package:flutter_riverpod/flutter_riverpod.dart';

/// ** Filters **

enum DoneFilter { all, done, undone }

final doneFilterProvider = StateProvider<DoneFilter>((ref) => DoneFilter.all);

enum TodoCategoryFilter { all, personal, work }

final todoCategoryFilterProvider = StateProvider<TodoCategoryFilter>((ref) {
  return TodoCategoryFilter.all;
});