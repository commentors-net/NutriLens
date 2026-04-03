import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'app/theme.dart';
import 'app/router.dart';
import 'core/services/app_log_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  await Firebase.initializeApp();
  await AppLogService.initialize();

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
