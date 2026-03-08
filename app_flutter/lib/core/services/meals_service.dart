import 'package:firebase_auth/firebase_auth.dart';
import 'package:dio/dio.dart';

/// Meals service with authentication enforcement
class MealsService {
  final String apiBaseUrl;
  final AuthService _authService;
  final Dio _dio = Dio();

  MealsService({
    required this.apiBaseUrl,
    required AuthService authService,
  }) : _authService = authService {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // Add auth token to all requests
          final token = await _authService.getIdToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
      ),
    );
  }

  /// Log a meal - REQUIRES authentication
  Future<Map<String, dynamic>> logMeal({
    required List<String> photoUrls,
    required String notes,
  }) async {
    // Enforce authentication
    if (!_authService.isAuthenticated) {
      throw Exception(
        'Authentication required to save recipes. Please sign in first.',
      );
    }

    try {
      final response = await _dio.post(
        '$apiBaseUrl/nutrilens/meals/log',
        data: {
          'photo_urls': photoUrls,
          'notes': notes,
          'logged_at': DateTime.now().toIso8601String(),
        },
      );

      if (response.statusCode == 201) {
        return response.data;
      } else {
        throw Exception('Failed to log meal: ${response.statusMessage}');
      }
    } catch (e) {
      throw Exception('Error logging meal: $e');
    }
  }

  /// Get user's meal history - REQUIRES authentication
  Future<List<Map<String, dynamic>>> getMealHistory() async {
    if (!_authService.isAuthenticated) {
      throw Exception(
        'Authentication required to access meal history.',
      );
    }

    try {
      final response = await _dio.get(
        '$apiBaseUrl/nutrilens/meals/history',
      );

      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(response.data ?? []);
      } else {
        throw Exception('Failed to fetch meal history');
      }
    } catch (e) {
      throw Exception('Error fetching meal history: $e');
    }
  }

  /// Get today's nutrition summary - REQUIRES authentication
  Future<Map<String, dynamic>> getTodayNutrition() async {
    if (!_authService.isAuthenticated) {
      throw Exception(
        'Authentication required to access nutrition data.',
      );
    }

    try {
      final response = await _dio.get(
        '$apiBaseUrl/nutrilens/meals/today-nutrition',
      );

      if (response.statusCode == 200) {
        return response.data ?? {};
      } else {
        throw Exception('Failed to fetch today\'s nutrition');
      }
    } catch (e) {
      throw Exception('Error fetching nutrition data: $e');
    }
  }

  /// Sync meals to backend - REQUIRES authentication
  Future<void> syncMeals() async {
    if (!_authService.isAuthenticated) {
      throw Exception(
        'Authentication required to sync meals. Please sign in first.',
      );
    }

    try {
      // Get local meals from SQLite and push to backend
      final response = await _dio.post(
        '$apiBaseUrl/nutrilens/meals/sync',
        data: {
          'sync_timestamp': DateTime.now().toIso8601String(),
        },
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to sync meals: ${response.statusMessage}');
      }
    } catch (e) {
      throw Exception('Error syncing meals: $e');
    }
  }

  /// Evaluate meal nutrition - REQUIRES authentication
  Future<Map<String, dynamic>> evaluateMeal({
    required String mealId,
  }) async {
    if (!_authService.isAuthenticated) {
      throw Exception(
        'Authentication required to evaluate meals.',
      );
    }

    try {
      final response = await _dio.post(
        '$apiBaseUrl/nutrilens/meals/$mealId/evaluate',
      );

      if (response.statusCode == 200) {
        return response.data ?? {};
      } else {
        throw Exception('Failed to evaluate meal');
      }
    } catch (e) {
      throw Exception('Error evaluating meal: $e');
    }
  }
}

// Import needed for the provider
import '../auth/auth_service.dart';
