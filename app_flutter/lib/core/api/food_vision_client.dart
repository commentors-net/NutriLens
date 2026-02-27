/// HTTP client for FoodVision API
/// Uses http package for MVP simplicity; can switch to Dio later.

import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/analyze_response.dart';

class FoodVisionClient {
  final String baseUrl;

  FoodVisionClient({this.baseUrl = 'http://localhost:8000'});

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
    final url = Uri.parse('$baseUrl/meals/analyze');
    final request = http.MultipartRequest('POST', url);

    // Add images
    for (final imagePath in imagePaths) {
      final file = http.MultipartFile.fromPath('images', imagePath);
      request.files.add(await file);
    }

    // Add metadata if provided
    if (platform != null || appVersion != null || photoCount != null) {
      final metadata = {
        if (platform != null || appVersion != null)
          'client': {
            if (platform != null) 'platform': platform,
            if (appVersion != null) 'app_version': appVersion,
          },
        if (photoCount != null)
          'capture': {'photo_count': photoCount},
        if (locale != null) 'locale': locale,
        if (timestamp != null) 'timestamp': timestamp.toIso8601String(),
      };
      request.fields['metadata'] = jsonEncode(metadata);
    }

    try {
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
    } catch (e) {
      rethrow;
    }
  }

  /// GET /meals/today
  /// Fetches today's meal totals
  Future<Map<String, dynamic>> getMealsToday() async {
    final url = Uri.parse('$baseUrl/meals/today');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        throw Exception('Failed to fetch today meals: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// POST /meals
  /// Saves a confirmed meal
  Future<Map<String, dynamic>> saveMeal(Map<String, dynamic> mealData) async {
    final url = Uri.parse('$baseUrl/meals');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(mealData),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        throw Exception('Failed to save meal: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }
}
