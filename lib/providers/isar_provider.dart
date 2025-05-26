import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';

import '../models/todo.dart';

final isarProvider = FutureProvider<Isar>((ref) async {
  Isar? isar;
  try {
    final dir = await getApplicationDocumentsDirectory();
    isar = await Isar.open(
      [TodoSchema],
      directory: dir.path,
      inspector: kDebugMode, // Enable inspector in debug mode
    );
    
    // Ensure the database is closed when the provider is disposed
    ref.onDispose(() async {
      try {
        await isar?.close();
      } catch (e) {
        debugPrint('Error closing Isar database: $e');
      }
    });

    return isar;
  } catch (e) {
    // Make sure to close the database if it was opened but an error occurred later
    await isar?.close();
    rethrow;
  }
});
