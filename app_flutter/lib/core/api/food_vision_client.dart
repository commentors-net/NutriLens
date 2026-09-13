import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foodvision/core/models/analyze_response.dart';
import 'package:foodvision/core/models/daily_totals.dart';
import 'package:foodvision/core/models/meal_history.dart';
import 'package:foodvision/core/models/synthesize_response.dart';
import 'package:foodvision/core/auth/auth_service.dart';
import 'package:foodvision/core/config/environment.dart';
import 'package:foodvision/core/utils/device_info.dart';
import 'api_config.dart';

class FoodVisionClient {
  final String baseUrl;
  final AuthService? authService;

  FoodVisionClient({
    this.baseUrl = kBackendBaseUrl,
    this.authService,
  });

  Future<Map<String, String>> _getAuthHeaders() async {
    final headers = <String, String>{};
    final token = await authService?.getIdToken();
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  /// POST /meals/analyze
  /// Uploads multiple images and optional metadata for analysis
  Future<AnalyzeMealResponse> analyzeMeal({
    required List<String> imagePaths,
    String? platform,
    String? appVersion,
    int? photoCount,
    String? locale,
    DateTime? timestamp,
  }) async {
    final effectivePlatform = platform ?? DeviceInfo.getDevicePlatform();
    final effectiveAppVersion = appVersion ?? DeviceInfo.getAppVersion();
    final effectiveLocale = locale ?? DeviceInfo.getDeviceLocale();
    final effectiveTimestamp = timestamp ?? DateTime.now();

    final url = Uri.parse('$baseUrl/meals/analyze');
    final request = http.MultipartRequest('POST', url);
    final authHeaders = await _getAuthHeaders();
    request.headers.addAll(authHeaders);

    // Add images
    for (final imagePath in imagePaths) {
      if (File(imagePath).existsSync()) {
        final file = await http.MultipartFile.fromPath('images', imagePath);
        request.files.add(file);
      }
    }

    // Add metadata dynamically from device context
    final metadata = {
      'client': {
        'platform': effectivePlatform,
        'app_version': effectiveAppVersion,
      },
      'capture': {'photo_count': photoCount ?? imagePaths.length},
      'locale': effectiveLocale,
      'timestamp': effectiveTimestamp.toIso8601String(),
    };
    request.fields['metadata'] = jsonEncode(metadata);

    final response = await request.send();
    final responseBody = await response.stream.bytesToString();

    if (response.statusCode == 200) {
      final json = jsonDecode(responseBody) as Map<String, dynamic>;
      return AnalyzeMealResponse.fromJson(json);
    } else {
      throw Exception(
        'Failed to analyze meal: ${response.statusCode} - $responseBody',
      );
    }
  }

  /// GET /meals/today — typed response
  Future<DailyTotals> getMealsToday() async {
    final url = Uri.parse('$baseUrl/meals/today');
    final authHeaders = await _getAuthHeaders();
    final response = await http.get(url, headers: authHeaders);
    if (response.statusCode == 200) {
      return DailyTotals.fromJson(
          jsonDecode(response.body) as Map<String, dynamic>);
    } else {
      throw Exception('Failed to fetch today meals: ${response.statusCode}');
    }
  }

  /// POST /meals — save a confirmed meal built from an AnalyzeMealResponse.
  Future<SaveMealResult> saveMealFromAnalysis(
    AnalyzeMealResponse analysis, {
    List<String> imagePaths = const [],
  }) async {
    final payload = {
      'items': analysis.items
          .map((item) => {
                'label': item.label,
                'grams': item.gramsEstimate,
                'original_label': item.originalLabel,
                'original_grams': item.originalGramsEstimate,
                'corrected': item.isCorrected,
                'macros': {
                  'kcal': item.macros.kcal,
                  'protein_g': item.macros.proteinG,
                  'carbs_g': item.macros.carbsG,
                  'fat_g': item.macros.fatG,
                },
              })
          .toList(),
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      'image_urls': <String>[],
    };

    final authHeaders = await _getAuthHeaders();
    http.Response response;
    if (imagePaths.isEmpty) {
      final url = Uri.parse('$baseUrl/meals/');
      response = await http.post(
        url,
        headers: {'Content-Type': 'application/json', ...authHeaders},
        body: jsonEncode(payload),
      );
    } else {
      final url = Uri.parse('$baseUrl/meals/with-images');
      final request = http.MultipartRequest('POST', url);
      request.headers.addAll(authHeaders);
      request.fields['payload'] = jsonEncode(payload);
      for (final imagePath in imagePaths) {
        if (File(imagePath).existsSync()) {
          final file = await http.MultipartFile.fromPath('images', imagePath);
          request.files.add(file);
        }
      }
      final streamed = await request.send();
      final body = await streamed.stream.bytesToString();
      response = http.Response(body, streamed.statusCode, headers: streamed.headers);
    }

    if (response.statusCode == 200 || response.statusCode == 201) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final mealId = json['meal_id'] as String? ?? 'saved';
      final rawUrls = json['image_urls'] as List<dynamic>? ?? [];
      final imageUrls = rawUrls.whereType<String>().toList();
      return SaveMealResult(mealId: mealId, imageUrls: imageUrls);
    } else {
      throw Exception(
        'Failed to save meal: ${response.statusCode} - ${response.body}',
      );
    }
  }

  /// GET /meals/range?start=YYYY-MM-DD&end=YYYY-MM-DD
  Future<MealHistoryResponse> getMealsByRange({
    required String start,
    required String end,
  }) async {
    final url = Uri.parse('$baseUrl/meals/range?start=$start&end=$end');
    final authHeaders = await _getAuthHeaders();
    final response = await http.get(url, headers: authHeaders);
    if (response.statusCode == 200) {
      return MealHistoryResponse.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    } else {
      throw Exception('Failed to fetch meal history: ${response.statusCode}');
    }
  }

  /// GET /meals/export?start=YYYY-MM-DD&end=YYYY-MM-DD&format=csv|pdf
  Future<List<int>> exportMeals({
    required String start,
    required String end,
    String format = 'csv',
  }) async {
    final url = Uri.parse(
        '$baseUrl/meals/export?start=$start&end=$end&format=$format');
    final authHeaders = await _getAuthHeaders();
    final response = await http.get(url, headers: authHeaders);
    if (response.statusCode == 200) {
      return response.bodyBytes;
    } else {
      throw Exception('Failed to export meals: ${response.statusCode}');
    }
  }

  /// POST /meals/synthesize — Reconcile initial cloud analysis with local LLM analysis
  Future<SynthesizeMealResponse> synthesizeMeal({
    String? mealId,
    required Map<String, dynamic> cloudAnalysis,
    required Map<String, dynamic> localAnalysis,
    String? notes,
  }) async {
    final url = Uri.parse('$baseUrl/meals/synthesize');
    final authHeaders = await _getAuthHeaders();
    authHeaders['Content-Type'] = 'application/json';

    final payload = {
      'meal_id': mealId,
      'cloud_analysis': cloudAnalysis,
      'local_analysis': localAnalysis,
      'notes': notes,
    };

    final response = await http.post(
      url,
      headers: authHeaders,
      body: jsonEncode(payload),
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return SynthesizeMealResponse.fromJson(json);
    } else {
      throw Exception('Failed to synthesize consensus: ${response.statusCode} - ${response.body}');
    }
  }
}

class SaveMealResult {
  final String mealId;
  final List<String> imageUrls;

  const SaveMealResult({
    required this.mealId,
    this.imageUrls = const [],
  });
}

final foodVisionClientProvider = Provider<FoodVisionClient>((ref) {
  final baseUrl = ref.watch(apiBaseUrlProvider);
  final authService = ref.watch(authServiceProvider);
  return FoodVisionClient(baseUrl: baseUrl, authService: authService);
});
