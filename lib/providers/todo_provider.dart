import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:interview_todos/models/openai_response.dart';
import 'package:interview_todos/services/local_notifications.dart';
import 'package:isar/isar.dart';

import '../models/todo.dart';
import 'isar_provider.dart';

final todoListProvider = StateNotifierProvider<TodoNotifier, AsyncValue<List<Todo>>>((ref) {
  final isarAsync = ref.watch(isarProvider);

  return isarAsync.when(
    data: (isar) => TodoNotifier(isar),
    loading: () => TodoNotifier(null),
    error: (e, st) => throw e,
  );
}, dependencies: [isarProvider]);

class TodoNotifier extends StateNotifier<AsyncValue<List<Todo>>> {
  final Isar? isar;

  TodoNotifier(this.isar) : super(const AsyncValue.loading()) {
    if (isar != null) {
      loadTodos();
    }
  }

  Future<void> loadTodos() async {
    if (isar == null) return;
    final todos = await isar!.todos.where().findAll();
    state = AsyncValue.data(todos);
  }

  Future<void> addTodo({required String title, TodoCategory? category}) async {
    if (isar == null) return;
    final todo = Todo(title: title, isDone: false, category: category ?? TodoCategory.personal);
    await isar!.writeTxn(() async {
      await isar!.todos.put(todo);
    });
    await loadTodos();
  }

  Future<void> addTodosFromOpenAI({required List<OpenAIResponse> responses}) async {
    if (isar == null) return;
    final todos = responses
        .map(
          (response) => Todo(
        title: response.title,
        description: response.description,
        isDone: false,
        category: response.category == 'personal' ? TodoCategory.personal : TodoCategory.work,
            dueDate: DateTime.tryParse(response.dateTime),
          ),
        )
        .toList();

    await isar!.writeTxn<List<Id>>(() async {
      return isar!.todos.putAll(todos);
    });

    final newTodosWithDueDates = todos.where((todo) => todo.dueDate != null).toList();

    for (final todo in newTodosWithDueDates) {
      LocalNotifications.scheduleNotification(id: todo.id, body: todo.title, scheduledDate: todo.dueDate!);
    }
    await loadTodos();
  }

  Future<void> toggleTodo(Todo todo) async {
    if (isar == null) return;
    await isar!.writeTxn(() async {
      todo.isDone = !todo.isDone;
      await isar!.todos.put(todo);
    });
    await loadTodos();
  }

  Future<void> updateTodo(Todo updated) async {
    if (isar == null) return;
    final oldDate = updated.dueDate;

    // Only proceed if the date actually changed
    if (updated.dueDate != oldDate) {
      // Update the model
      updated.dueDate = updated.dueDate;

      // Cancel any existing notification
      LocalNotifications.cancelNotification(updated.id);

      // Schedule a new notification if the date is not null
      if (updated.dueDate != null && updated.dueDate!.isAfter(DateTime.now())) {
        LocalNotifications.scheduleNotification(id: updated.id, body: updated.title, scheduledDate: updated.dueDate!);
      }
    }
    await isar!.writeTxn(() async => await isar!.todos.put(updated));
    await loadTodos();
  }

  void deleteTodo(int id) {
    state = AsyncValue.data([
      for (final todo in state.valueOrNull ?? [])
        if (todo.id != id) todo,
    ]);
    LocalNotifications.cancelNotification(id);
    isar!.writeTxn(() => isar!.todos.delete(id));
  }
}
