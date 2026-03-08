import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Environment configuration
enum AppEnvironment {
  debug,   // Localhost
  live,    // Cloud Run
}

extension AppEnvironmentName on AppEnvironment {
  String get displayName {
    switch (this) {
      case AppEnvironment.debug:
        return 'Debug (Localhost)';
      case AppEnvironment.live:
        return 'Live (Cloud)';
    }
  }

  String get apiBaseUrl {
    switch (this) {
      case AppEnvironment.debug:
        // Change this to your local machine IP if needed
        // Example: 'http://192.168.0.10:8000'
        return 'http://10.0.2.2:8000'; // Android emulator localhost
      case AppEnvironment.live:
        return 'https://nutrilens-api-2ajzj2dbrq-uc.a.run.app';
    }
  }
}

/// Environment state notifier
class EnvironmentNotifier extends StateNotifier<AppEnvironment> {
  final SharedPreferences prefs;

  EnvironmentNotifier(this.prefs)
      : super(_loadEnvironment(prefs));

  static AppEnvironment _loadEnvironment(SharedPreferences prefs) {
    final savedEnv = prefs.getString('app_environment') ?? 'live';
    return savedEnv == 'debug' ? AppEnvironment.debug : AppEnvironment.live;
  }

  Future<void> setEnvironment(AppEnvironment env) async {
    await prefs.setString(
      'app_environment',
      env == AppEnvironment.debug ? 'debug' : 'live',
    );
    state = env;
  }

  String get currentApiUrl => state.apiBaseUrl;
}

/// Provider for SharedPreferences
final sharedPreferencesProvider = FutureProvider<SharedPreferences>((ref) async {
  return SharedPreferences.getInstance();
});

/// Provider for environment
final environmentProvider =
    StateNotifierProvider<EnvironmentNotifier, AppEnvironment>((ref) {
  final prefsAsync = ref.watch(sharedPreferencesProvider);
  
  return prefsAsync.when(
    data: (prefs) => EnvironmentNotifier(prefs),
    loading: () => EnvironmentNotifier(null),
    error: (err, st) {
      // Fallback if SharedPreferences fails
      throw Exception('Failed to load environment: $err');
    },
  );
});

/// Provider to get current API base URL
final apiBaseUrlProvider = Provider<String>((ref) {
  final environment = ref.watch(environmentProvider);
  return environment.apiBaseUrl;
});
