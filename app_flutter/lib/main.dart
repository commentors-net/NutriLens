import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'app/theme.dart';
import 'app/router.dart';
import 'core/services/app_log_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase (fail-safe across platforms)
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Firebase initialization notice: $e');
  }

  try {
    await AppLogService.initialize();
  } catch (e) {
    debugPrint('AppLogService initialization notice: $e');
  }

  runApp(const ProviderScope(child: FoodVisionApp()));
}

class FoodVisionApp extends ConsumerWidget {
  const FoodVisionApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(goRouterProvider);
    
    return MaterialApp.router(
      title: 'FoodVision',
      theme: appTheme,
      routerConfig: router,
    );
  }
}
