import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:interview_todos/models/todo.dart';
import 'package:interview_todos/providers/filter_provider.dart';
import 'package:interview_todos/providers/tab_provider.dart';
import 'package:interview_todos/providers/todo_provider.dart';
import 'package:interview_todos/screens/detail_screen.dart';
import 'package:intl/intl.dart';

class TodoListView extends ConsumerStatefulWidget {
  final List<Todo> todos;
  final bool showInput;
  final bool applyFilter;

  const TodoListView({required this.todos, this.showInput = true, this.applyFilter = false, super.key});

  @override
  ConsumerState<TodoListView> createState() => _TodoListViewState();
}

class _TodoListViewState extends ConsumerState<TodoListView> {
  late List<Todo> filteredTodos = [];
  final TextEditingController _emptyStateController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final todosAsync = ref.watch(todoListProvider);
    final filter = ref.watch(todoCategoryFilterProvider);

    todosAsync.whenData((todos) {
      filteredTodos = todos.where((t) {
        final categoryMatch = filter == TodoCategoryFilter.all || t.category.name == filter.name;
        final completionMatch = widget.showInput ? !t.isDone : t.isDone;
        return categoryMatch && completionMatch;
      }).toList();
    });

    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    if (filteredTodos.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(widget.showInput ? '📝' : '✅', style: const TextStyle(fontSize: 72)),
              const SizedBox(height: 16),
              Text(
                widget.showInput ? 'No tasks yet.\nLet’s get started!' : 'All done!\nNo completed tasks.',
                style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
              if (widget.showInput) ...[
                const SizedBox(height: 24),
                Material(
                  elevation: 2,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      controller: _emptyStateController,
                      decoration: const InputDecoration(hintText: 'Add a new todo...', border: InputBorder.none),
                      textInputAction: TextInputAction.done,
                      onSubmitted: (value) {
                        final text = value.trim();
                        TodoCategory category = TodoCategory.personal;
                        if (filter == TodoCategoryFilter.work) {
                          category = TodoCategory.work;
                        }
                        if (text.isNotEmpty) {
                          ref.read(todoListProvider.notifier).addTodo(title: text, category: category);
                          _emptyStateController.clear();
                        }
                      },
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 16),
      itemCount: filteredTodos.length + (widget.showInput ? 1 : 0),
      separatorBuilder: (_, __) => const Divider(indent: 16, endIndent: 16),
      itemBuilder: (context, index) {
        if (widget.showInput && index == filteredTodos.length) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Material(
              elevation: 1,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: TextField(
                  controller: TextEditingController(),
                  decoration: const InputDecoration(hintText: 'Add another todo...', border: InputBorder.none),
                  textInputAction: TextInputAction.done,
                  onSubmitted: (value) {
                    final text = value.trim();
                    TodoCategory category = TodoCategory.personal;
                    if (filter == TodoCategoryFilter.work) {
                      category = TodoCategory.work;
                    }
                    if (text.isNotEmpty) {
                      ref.read(todoListProvider.notifier).addTodo(title: text, category: category);
                    }
                  },
                ),
              ),
            ),
          );
        }

        final todo = filteredTodos[index];
        return Dismissible(
          key: Key(todo.id.toString()),
          background: Container(
            padding: const EdgeInsets.only(left: 16),
            alignment: Alignment.centerLeft,
            color: Colors.red,
            child: const Icon(Icons.delete, color: Colors.white),
          ),
          onDismissed: (_) => ref.read(todoListProvider.notifier).deleteTodo(todo.id),
          child: ListTile(
            leading: Checkbox(
              value: todo.isDone,
              onChanged: (_) => ref.read(todoListProvider.notifier).toggleTodo(todo),
            ),
            title: Text(
              todo.title,
              style: textTheme.bodyLarge?.copyWith(
                decoration: todo.isDone ? TextDecoration.lineThrough : null,
                color: todo.isDone ? Colors.grey : null,
              ),
            ),
            subtitle: todo.dueDate != null
                ? _DueDateText(dueDate: todo.dueDate, isDone: todo.isDone, textTheme: textTheme)
                : null,
            trailing: IconButton(
              icon: const Icon(Icons.info_outline),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => TodoDetailScreen(todo: todo, allowEditing: ref.read(currentTabProvider) == 0),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

/// A widget that displays the due date of a todo in red if it is overdue.
class _DueDateText extends StatefulWidget {
  final DateTime? dueDate;
  final bool isDone;
  final TextTheme textTheme;

  const _DueDateText({required this.dueDate, required this.isDone, required this.textTheme});

  @override
  State<_DueDateText> createState() => _DueDateTextState();
}

class _DueDateTextState extends State<_DueDateText> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _scheduleNextUpdate();
  }

  void _scheduleNextUpdate() {
    final now = DateTime.now();
    final nextMinute = DateTime(now.year, now.month, now.day, now.hour, now.minute + 1);
    final timeUntilNextMinute = nextMinute.difference(now);

    // Wait until the start of the next minute
    _timer = Timer(timeUntilNextMinute, () {
      setState(() {});
      // Then repeat every minute exactly
      _timer = Timer.periodic(const Duration(minutes: 1), (_) {
        setState(() {});
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.dueDate == null) return const SizedBox.shrink();

    final isOverdue = widget.dueDate!.isBefore(DateTime.now()) && !widget.isDone;

    return Text(dueDateString, style: widget.textTheme.bodyMedium?.copyWith(color: isOverdue ? Colors.red : null));
  }

  String get dueDateString {
    if (widget.dueDate == null) return '';

    final now = DateTime.now();
    final due = widget.dueDate!.toLocal();

    final today = DateTime(now.year, now.month, now.day);
    final dueDay = DateTime(due.year, due.month, due.day);

    final differenceInDays = dueDay.difference(today).inDays;

    String dayLabel;
    if (differenceInDays == 0) {
      dayLabel = 'Today';
    } else if (differenceInDays == 1) {
      dayLabel = 'Tomorrow';
    } else if (differenceInDays > 1 && differenceInDays < 7) {
      dayLabel = DateFormat.EEEE().format(due); // e.g., Friday
    } else {
      dayLabel = DateFormat.yMMMd().format(due); // e.g., May 30, 2025
    }

    final timeLabel = DateFormat.jm().format(due);

    return '$dayLabel, $timeLabel';
  }
}
