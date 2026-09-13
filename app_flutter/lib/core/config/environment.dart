import 'dart:io' show Platform;
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
        // Automatically adapt between iOS simulator (127.0.0.1) and Android emulator (10.0.2.2)
        try {
          if (Platform.isIOS) {
            return 'http://127.0.0.1:8000';
          }
        } catch (_) {}
        return 'http://10.0.2.2:8000';
      case AppEnvironment.live:
        return 'https://nutrilens-api-2ajzj2dbrq-uc.a.run.app';
    }
  }
}

/// Environment state notifier
class EnvironmentNotifier extends StateNotifier<AppEnvironment> {
  final SharedPreferences? prefs;

  EnvironmentNotifier(this.prefs)
      : super(_loadEnvironment(prefs));

  static AppEnvironment _loadEnvironment(SharedPreferences? prefs) {
    if (prefs == null) {
      return AppEnvironment.live;
    }
    final savedEnv = prefs.getString('app_environment') ?? 'live';
    return savedEnv == 'debug' ? AppEnvironment.debug : AppEnvironment.live;
  }

  Future<void> setEnvironment(AppEnvironment env) async {
    if (prefs != null) {
      await prefs!.setString(
        'app_environment',
        env == AppEnvironment.debug ? 'debug' : 'live',
      );
    }
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
    error: (err, st) => EnvironmentNotifier(null),
  );
});

/// Provider to get current API base URL
final apiBaseUrlProvider = Provider<String>((ref) {
  final environment = ref.watch(environmentProvider);
  return environment.apiBaseUrl;
});
