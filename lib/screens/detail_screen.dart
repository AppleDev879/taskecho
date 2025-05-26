import 'package:cupertino_calendar_picker/cupertino_calendar_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:interview_todos/services/local_notifications.dart';

import '../models/todo.dart';
import '../providers/todo_provider.dart';

class TodoDetailScreen extends ConsumerStatefulWidget {
  final Todo todo;
  final bool allowEditing;

  const TodoDetailScreen({super.key, required this.todo, this.allowEditing = true});

  @override
  ConsumerState<TodoDetailScreen> createState() => _TodoDetailScreenState();
}

class _TodoDetailScreenState extends ConsumerState<TodoDetailScreen> {
  late TextEditingController _titleController;
  late TodoCategory _selectedCategory;
  DateTime? _selectedDate;
  bool _hasDueDate = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.todo.title);
    _selectedCategory = widget.todo.category;
    _selectedDate = widget.todo.dueDate;
    _hasDueDate = widget.todo.dueDate != null;

    if (widget.allowEditing) {
      _titleController.addListener(_autoSaveTitle);
    }
  }

  void _autoSaveTitle() {
    final trimmed = _titleController.text.trim();
    if (trimmed != widget.todo.title) {
      widget.todo.title = trimmed;
      ref.read(todoListProvider.notifier).updateTodo(widget.todo);
    }
  }

  void _autoSaveCategory(TodoCategory category) {
    if (category != widget.todo.category) {
      widget.todo.category = category;
      ref.read(todoListProvider.notifier).updateTodo(widget.todo);
    }
  }

  void _autoSaveDueDate(DateTime? newDate) {
    final notifier = ref.read(todoListProvider.notifier);
    final oldDate = widget.todo.dueDate;

    // Only proceed if the date actually changed
    if (newDate != oldDate) {
      // Update the model
      widget.todo.dueDate = newDate;
      notifier.updateTodo(widget.todo);

      // Cancel any existing notification
      LocalNotifications.cancelNotification(widget.todo.id);

      // Schedule a new notification if the date is not null
      if (newDate != null && newDate.isAfter(DateTime.now())) {
        LocalNotifications.scheduleNotification(
          id: widget.todo.id,
          body: widget.todo.title,
          scheduledDate: newDate,
        );
      }
    }
  }

  void _toggleDueDate(bool value) {
    setState(() => _hasDueDate = value);
    if (!value) {
      _selectedDate = null;
      _autoSaveDueDate(null);
    } else {
      _selectedDate = _validInitialDate;
      _autoSaveDueDate(_validInitialDate);
    }
  }

  @override
  void dispose() {
    if (widget.allowEditing) {
      _titleController.removeListener(_autoSaveTitle);
    }
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Edit To-Do")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(labelText: 'Title'),
            enabled: widget.allowEditing,
          ),
          const SizedBox(height: 16),

          TextField(
            controller: TextEditingController(text: widget.todo.description),
            decoration: const InputDecoration(labelText: 'Description'),
            minLines: 4,
            maxLines: null,
            enabled: widget.allowEditing,
          ),
          const SizedBox(height: 16),

          DropdownButtonFormField<TodoCategory>(
            value: _selectedCategory,
            decoration: const InputDecoration(labelText: 'Category'),
            items: TodoCategory.values
                .map((c) => DropdownMenuItem(value: c, child: Text(c.name.capitalize())))
                .toList(),
            onChanged: widget.allowEditing
                ? (value) {
                    if (value != null) {
                      setState(() => _selectedCategory = value);
                      _autoSaveCategory(value);
                    }
                  }
                : null,
          ),
          const SizedBox(height: 16),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Has due date"),
              Switch(value: _hasDueDate, onChanged: widget.allowEditing ? _toggleDueDate : null),
            ],
          ),

          if (_hasDueDate)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: AbsorbPointer(
                absorbing: !widget.allowEditing,
                child: CupertinoCalendarPickerButton(
                  initialDateTime: _validInitialDate,
                  minimumDateTime: _validMinimumDate,
                  maximumDateTime: DateTime(2100),
                  mode: CupertinoCalendarMode.dateTime,
                  onCompleted: (date) {
                    DateTime? roundedDate;
                    if (date != null) {
                      roundedDate = stripSeconds(date);
                    }

                    setState(() => _selectedDate = roundedDate);
                    _autoSaveDueDate(roundedDate);
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }

  DateTime get _validInitialDate {
    return _selectedDate ?? stripSeconds(DateTime.now().add(const Duration(minutes: 1)));
  }

  DateTime get _validMinimumDate {
    if (_selectedDate?.isBefore(DateTime.now()) == true) {
      return _selectedDate!;
    }
    return stripSeconds(DateTime.now().add(const Duration(minutes: 1)));
  }

  DateTime stripSeconds(DateTime dt) {
    return DateTime(dt.year, dt.month, dt.day, dt.hour, dt.minute);
  }
}

extension StringCap on String {
  String capitalize() => isEmpty ? this : this[0].toUpperCase() + substring(1);
}
