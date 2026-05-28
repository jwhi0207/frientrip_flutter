import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'firebase_options.dart';
import 'router.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const ProviderScope(child: FrientrippApp()));
}

class FrientrippApp extends ConsumerWidget {
  const FrientrippApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'Frientrip',
      theme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
      themeMode: ThemeMode.system,
      routerConfig: router,
    );
  }
}
