import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app/theme.dart';
import 'app/router.dart';

void main() {
  runApp(const ProviderScope(child: FoodVisionApp()));
}

class FoodVisionApp extends StatelessWidget {
  const FoodVisionApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'FoodVision',
      theme: appTheme,
      routerConfig: appRouter,
    );
  }
}
