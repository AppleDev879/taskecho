import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:interview_todos/providers/filter_provider.dart';
import 'package:interview_todos/providers/tab_provider.dart';
import 'package:interview_todos/providers/todo_provider.dart';
import 'package:interview_todos/widgets/recording_sheet.dart';
import 'package:interview_todos/widgets/todo_list_view.dart';

class MainScreen extends ConsumerWidget {
  const MainScreen({super.key, required this.currentTab});

  final int currentTab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todosAsync = ref.watch(todoListProvider);

    return Scaffold(
      appBar: AppBar(title: Text(currentTab == 0 ? 'To-Do List' : 'Completed Tasks')),
      body: Column(
        children: [
          if (currentTab == 0) Padding(padding: EdgeInsets.all(8), child: _FilterChips()),
          Expanded(
            child: todosAsync.when(
              data: (todos) {
                final undone = todos.where((t) => !t.isDone).toList();
                return TodoListView(todos: undone, showInput: currentTab == 0, applyFilter: currentTab == 0);
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, st) => Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentTab,
        onTap: (index) => ref.read(currentTabProvider.notifier).state = index,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.list_alt), label: 'To-Do'),
          BottomNavigationBarItem(icon: Icon(Icons.check_circle), label: 'Done'),
        ],
      ),
      floatingActionButton: currentTab == 0
          ? FloatingActionButton(
              onPressed: () {
                requestMicPermissionAndShowModal(context);
              },
              child: const Icon(Icons.mic),
            )
          : null,
    );
  }
}

class _FilterChips extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoryFilter = ref.watch(todoCategoryFilterProvider);

    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        ...TodoCategoryFilter.values.map((cat) {
          return ChoiceChip(
            label: Text(cat.name.toUpperCase()),
            selected: cat == categoryFilter,
            onSelected: (_) {
              ref.read(todoCategoryFilterProvider.notifier).state = cat;
            },
          );
        }),
      ],
    );
  }
}

extension StringCap on String {
  String capitalize() => this[0].toUpperCase() + substring(1);
}
