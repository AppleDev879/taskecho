import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:interview_todos/providers/tab_provider.dart';
import 'package:interview_todos/screens/main_screen.dart';

import 'services/local_notifications.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Future.wait([
    dotenv.load(),
    LocalNotifications.init(),
  ]);
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentTab = ref.watch(currentTabProvider);

    return MaterialApp(
      title: 'To-Do List',
      home: MainScreen(currentTab: currentTab),
    );
  }
}