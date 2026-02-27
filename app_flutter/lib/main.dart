import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app/theme.dart';
import 'app/router.dart';
import 'features/capture/capture_screen.dart';

void main() {
  runApp(const ProviderScope(child: FoodVisionApp()));
}

class FoodVisionApp extends StatelessWidget {
  const FoodVisionApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FoodVision',
      theme: appTheme,
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('FoodVision'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Today\'s Summary'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                // Navigate to capture screen
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const CaptureScreen(),
                  ),
                );
              },
              child: const Text('+ New Meal'),
            ),
          ],
        ),
      ),
    );
  }
}
