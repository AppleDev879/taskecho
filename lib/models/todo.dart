import 'package:isar/isar.dart';

part 'todo.g.dart';

@collection
class Todo {

  Todo({
    required this.title,
    this.description,
    this.isDone = false,
    this.category = TodoCategory.personal,
    this.dueDate,
  });

  Id id = Isar.autoIncrement;

  String title;

  String? description;

  bool isDone;

  @enumerated
  TodoCategory category;

  DateTime? dueDate;
}

enum TodoCategory {
  personal,
  work,
}

